const std = @import("std");

const ColorMap = @This();

offset: u16,
hashmap: HashMap,

pub const Color = extern struct {
    r: u16,
    g: u16,
    b: u16,

    pub const black = rgb(0, 0, 0);
    pub const white = rgb(0xFFFF, 0xFFFF, 0xFFFF);

    pub fn rgb(r: u16, g: u16, b: u16) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    fn pack(self: Color) u48 {
        return @bitCast(self);
    }

    fn unpack(self: u48) Color {
        return @bitCast(self);
    }
};

const HashMap = std.AutoArrayHashMapUnmanaged(u48, usize);

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader) !ColorMap {
    const first_color = try r.takeInt(u16, .big);
    const number_of_colors = try r.takeInt(u16, .big);

    var entries: HashMap.DataList = .{};
    errdefer entries.deinit(allocator);

    try entries.setCapacity(allocator, number_of_colors);

    // capacity preallocated; direct fill
    entries.len = number_of_colors;

    const keys = entries.items(.key);
    const indexes = entries.items(.value);

    for (0..number_of_colors) |i| {
        keys[i] = (try r.takeStruct(Color, .big)).pack();
        indexes[i] = i;
    }

    var reverse: HashMap = .{ .entries = entries };
    try reverse.reIndex(allocator);

    return .{
        .offset = first_color,
        .hashmap = reverse,
    };
}

pub fn write(self: *const ColorMap, w: *std.Io.Writer) !void {
    try w.writeSliceEndian(u16, &[_]u16{ self.offset, @intCast(self.hashmap.count()) }, .big);
    for (self.hashmap.keys()) |key| {
        try w.writeSliceEndian(u16, &@as([3]u16, @bitCast(key)), .big);
    }
}

pub fn deinit(self: *ColorMap, allocator: std.mem.Allocator) void {
    self.hashmap.deinit(allocator);
    self.* = undefined;
}

pub fn clone(self: *const ColorMap, allocator: std.mem.Allocator) !ColorMap {
    return .{
        .offset = self.offset,
        .hashmap = try self.hashmap.clone(allocator),
    };
}

pub fn getColor(self: *const ColorMap, index: usize) ?Color {
    if (index < self.offset) {
        return null;
    }

    const i = index - self.offset;
    if (self.hashmap.count() <= i) {
        return null;
    }

    return Color.unpack(self.hashmap.keys()[i]);
}

pub fn getIndex(self: *const ColorMap, color: Color) ?usize {
    if (self.hashmap.get(color.pack())) |i| {
        return i + self.offset;
    }

    return null;
}

test {
    const buf = [_]u8{
        0x00, 0x00, // offset
        0x00, 0x03, // count,

        // red
        0xFF, 0xFF, // red
        0x00, 0x00, // green
        0x00, 0x00, // blue

        // green
        0x00, 0x00, // red
        0xFF, 0xFF, // green
        0x00, 0x00, // blue

        // blue
        0x00, 0x00, // red
        0x00, 0x00, // green
        0xFF, 0xFF, // blue
    };

    var r = std.Io.Reader.fixed(&buf);

    var cm = try ColorMap.read(std.testing.allocator, &r);
    defer cm.deinit(std.testing.allocator);

    try std.testing.expectEqual(0, cm.offset);

    try std.testing.expectEqual(3, cm.hashmap.entries.capacity);
    try std.testing.expectEqual(cm.hashmap.entries.capacity, cm.hashmap.capacity());
    try std.testing.expectEqual(cm.hashmap.entries.capacity, cm.hashmap.count());

    try std.testing.expectEqual(Color{ .r = 0xFFFF, .g = 0x0000, .b = 0x0000 }, cm.getColor(0));
    try std.testing.expectEqual(Color{ .r = 0x0000, .g = 0xFFFF, .b = 0x0000 }, cm.getColor(1));
    try std.testing.expectEqual(Color{ .r = 0x0000, .g = 0x0000, .b = 0xFFFF }, cm.getColor(2));
    try std.testing.expectEqual(null, cm.getColor(3));

    try std.testing.expectEqual(0, cm.getIndex(.{ .r = 0xFFFF, .g = 0x0000, .b = 0x0000 }));
    try std.testing.expectEqual(1, cm.getIndex(.{ .r = 0x0000, .g = 0xFFFF, .b = 0x0000 }));
    try std.testing.expectEqual(2, cm.getIndex(.{ .r = 0x0000, .g = 0x0000, .b = 0xFFFF }));
    try std.testing.expectEqual(null, cm.getIndex(.{ .r = 0, .g = 0, .b = 0 }));

    var out = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer out.deinit();

    try cm.write(&out.writer);

    try std.testing.expectEqualSlices(u8, &buf, out.written());
}
