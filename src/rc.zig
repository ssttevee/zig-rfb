const std = @import("std");

fn Base(T: type) type {
    return struct {
        count: usize,
        value: T,

        fn from(value_ptr: *T) *@This() {
            return @fieldParentPtr("value", value_ptr);
        }
    };
}

pub fn Rc(T: type) type {
    return struct {
        const Self = @This();

        ptr: *T,

        pub fn init(allocator: std.mem.Allocator, value: T) !Self {
            const base = try allocator.create(Base(T));
            base.count = 1;
            base.value = value;
            return .{
                .ptr = &base.value,
            };
        }

        pub inline fn ref(self: Self) Self {
            Base(T).from(self.ptr).count += 1;
            return self;
        }

        pub inline fn asConst(self: Self) ConstRc(T) {
            return .{ .ptr = self.ptr };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            const base = Base(T).from(self.ptr);
            if (base.count > 1) {
                base.count -= 1;
                return;
            }

            if (@hasDecl(T, "deinit")) {
                const params = @typeInfo(@TypeOf(T.deinit)).@"fn".params;
                if (params.len == 1 and params[0].type == *T) {
                    self.ptr.deinit();
                } else if (params.len == 2 and params[0].type == *T and params[1].type == std.mem.Allocator) {
                    self.ptr.deinit(allocator);
                } else {
                    @compileError(std.fmt.comptimePrint("don't know how to deinit {}", .{T}));
                }
            }

            allocator.destroy(base);
            self.* = undefined;
        }
    };
}

pub fn ConstRc(T: type) type {
    return struct {
        const Self = @This();

        ptr: *const T,

        pub inline fn init(allocator: std.mem.Allocator, value: T) !Self {
            return (try Rc(T).init(allocator, value)).asConst();
        }

        pub inline fn ref(self: Self) Self {
            Base(T).from(@constCast(self.ptr)).count += 1;
            return self;
        }

        pub inline fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            @as(*Rc(T), @ptrCast(self)).deinit(allocator);
        }
    };
}
