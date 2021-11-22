const std = @import("std");
const root = @import("../../root.zig");

const CutText = @This();

text: []const u8,

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader) !CutText {
    try r.discardAll(3);

    return .{
        .text = try r.readAlloc(allocator, try r.takeInt(u32, .big)),
    };
}

pub fn write(self: *const CutText, w: *std.Io.Writer) !void {
    try w.writeAll(&.{
        0, 0, 0, // padding
    });
    try w.writeInt(u32, @truncate(self.text.len), .big);
    try w.writeAll(self.text);
}

pub fn deinit(self: *CutText, allocator: std.mem.Allocator) void {
    allocator.free(self.text);
    self.* = undefined;
}
