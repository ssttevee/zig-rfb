const std = @import("std");
const assert = std.debug.assert;

fn reverseBytes(comptime bytes: usize, buf: []u8) void {
    comptime var i = 0;
    inline while (i < bytes / 2) {
        const tmp = buf[i];
        buf[i] = buf[bytes - i - 1];
        buf[bytes - i - 1] = tmp;

        i += 1;
    }
}

fn reverseBytesInType(comptime T: type, buf: []u8) void {
    switch (@typeInfo(T)) {
        .Int => |info| {
            comptime {
                if (0 != info.bits % 8) {
                    unreachable; // can only swap full bytes
                }
            }

            reverseBytes(info.bits / 8, buf);
        },
        .Struct => |st| {
            comptime var offset: usize = 0;
            inline for (st.fields) |field| {
                reverseBytesInType(field.field_type, buf[offset..]);

                offset += @sizeOf(field.field_type);
            }
        },
        .Array => |arr| {
            const elementSize = @sizeOf(arr.child);

            comptime var i = 0;
            inline while (i < arr.len) {
                reverseBytesInType(arr.child, buf[elementSize * i..]);

                i += 1;
            }
        },
        else => {
            // do nothing
        }
    }
}

pub fn memcpy(buf: []u8, value: anytype) usize {
    const valueType = @TypeOf(value);
    const valueTypeInfo = @typeInfo(valueType);
    switch (valueTypeInfo) {
        .Struct => |s| if (s.is_tuple) {
            var offset: usize = 0;
            inline for (s.fields) |field| {
                const n = memcpy(buf[offset..], @field(value, field.name));
                offset += n;
            }

            return offset;
        } else {
            comptime assert(s.layout != std.builtin.TypeInfo.ContainerLayout.Auto);

            const n = @sizeOf(valueType);
            assert(buf.len >= n);

            @memcpy(buf.ptr, std.mem.asBytes(&value), n);

            reverseBytesInType(valueType, buf);

            return n;
        },
        .Enum => |e| {
            comptime assert(@typeInfo(e.tag_type).Int.bits % 8 == 0);

            return memcpy(buf, @enumToInt(value));
        },
        .Int => |i| {
            const n: usize = i.bits / 8;
            assert(buf.len >= n);

            @memcpy(buf.ptr, std.mem.asBytes(&value), n);

            reverseBytesInType(valueType, buf);

            return n;
        },
        .Array => |arr| {
            if (arr.child == u8) {
                @memcpy(buf.ptr, &value[0], arr.len);
                return arr.len;
            } else {
                unreachable;
            }
        },
        .Pointer => |ptr| {
            if (ptr.size == std.builtin.TypeInfo.Pointer.Size.Slice and ptr.child == u8) {
                @memcpy(buf.ptr, value.ptr, value.len);
                return value.len;
            } else {
                unreachable;
            }
        },
        else => |info| {
            std.debug.print("memcpy not implemented for {s} {any}\n", .{@tagName(info), valueType});
            unreachable;
        }
    }
}

test {
    const Foo = packed struct {
        bar: u16,
        baz: u16,
    };

    var buf: [4]u8 = undefined;
    assert(memcpy(&buf, Foo{.bar = 640, .baz = 480}) == 4);
    assert(buf[0] == 2);
    assert(buf[1] == 128);
    assert(buf[2] == 1);
    assert(buf[3] == 224);
}

test {
    var buf: [2]u8 = undefined;
    assert(memcpy(&buf, @as(u16, 640)) == 2);
    assert(buf[0] == 2);
    assert(buf[1] == 128);
}

test {
    var buf: [4]u8 = undefined;
    assert(memcpy(&buf, .{@as(u16, 640), @as(u16, 480)}) == 4);
    assert(buf[0] == 2);
    assert(buf[1] == 128);
    assert(buf[2] == 1);
    assert(buf[3] == 224);
}

test {
    const Bar = packed struct {
        data: [2]u8,
    };
    const Foo = packed struct {
        bar: Bar,
        baz: u16,
    };

    var buf: [4]u8 = undefined;
    assert(memcpy(&buf, Foo{.bar = .{ .data = [2]u8{1, 2} }, .baz = 480}) == 4);
    assert(buf[0] == 1);
    assert(buf[1] == 2);
    assert(buf[2] == 1);
    assert(buf[3] == 224);
}

test {
    const Foo = enum(u16) {
        bar = 640,
    };

    var buf: [2]u8 = undefined;
    assert(memcpy(&buf, Foo.bar) == 2);
    assert(buf[0] == 2);
    assert(buf[1] == 128);
}
