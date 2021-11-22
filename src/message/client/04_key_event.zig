const std = @import("std");
const root = @import("../../root.zig");

const KeySym = root.KeySym;

const KeyEvent = @This();

down: bool,
key: KeySym,

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader) !KeyEvent {
    _ = allocator;

    const down = (try r.takeByte()) != 0;
    _ = try r.takeByte(); // discard padding

    return .{
        .down = down,
        .key = .{
            .value = try r.takeInt(u32, .big),
        },
    };
}

pub fn write(self: *const KeyEvent, w: *std.Io.Writer) !void {
    try w.writeAll(&.{
        if (self.down) 1 else 0,
        0, 0, // padding
    });
    try w.writeInt(u32, self.key.value, .big);
}

pub fn deinit(self: *KeyEvent, allocator: std.mem.Allocator) void {
    _ = allocator;

    self.* = undefined;
}
