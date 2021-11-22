const std = @import("std");
const root = @import("../../root.zig");

const Point = root.Point;

const PointerEvent = @This();

button_state: std.StaticBitSet(8),
position: Point,

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader) !PointerEvent {
    _ = allocator;

    return .{
        .button_state = .{
            .mask = try r.takeByte(),
        },
        .position = .{
            .x = try r.takeInt(u16, .big),
            .y = try r.takeInt(u16, .big),
        },
    };
}

pub fn write(self: *const PointerEvent, w: *std.Io.Writer) !void {
    try w.writeAll(&.{
        self.button_state.mask,
    });
    try w.writeInt(u16, @truncate(self.position.x), .big);
    try w.writeInt(u16, @truncate(self.position.y), .big);
}

pub fn deinit(self: *PointerEvent, allocator: std.mem.Allocator) void {
    _ = allocator;

    self.* = undefined;
}
