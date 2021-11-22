const std = @import("std");
const root = @import("../../root.zig");

const Rectangle = root.Rectangle;

const FramebufferUpdateRequest = @This();

incremental: bool,
rect: Rectangle,

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader) !FramebufferUpdateRequest {
    _ = allocator;

    return .{
        .incremental = (try r.takeByte()) != 0,
        .rect = .{
            .x = try r.takeInt(u16, .big),
            .y = try r.takeInt(u16, .big),
            .w = try r.takeInt(u16, .big),
            .h = try r.takeInt(u16, .big),
        },
    };
}

pub fn write(self: *const FramebufferUpdateRequest, w: *std.Io.Writer) !void {
    try w.writeAll(&.{
        if (self.incremental) 1 else 0,
    });
    try w.writeInt(u16, @truncate(self.rect.x), .big);
    try w.writeInt(u16, @truncate(self.rect.y), .big);
    try w.writeInt(u16, @truncate(self.rect.w), .big);
    try w.writeInt(u16, @truncate(self.rect.h), .big);
}

pub fn deinit(self: *FramebufferUpdateRequest, allocator: std.mem.Allocator) void {
    _ = allocator;

    self.* = undefined;
}
