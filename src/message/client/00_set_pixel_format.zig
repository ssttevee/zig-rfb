const std = @import("std");
const root = @import("../../root.zig");

const PixelFormat = root.PixelFormat;

const SetPixelFormat = @This();

pixel_format: PixelFormat,

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader) !SetPixelFormat {
    _ = allocator;

    try r.discardAll(3); // discard padding

    return .{
        .pixel_format = try PixelFormat.read(r),
    };
}

pub fn write(self: *const SetPixelFormat, w: *std.Io.Writer) !void {
    try w.writeAll(&[_]u8{
        0, 0, 0, // padding
    });

    try self.pixel_format.write(w);
}

pub fn deinit(self: *SetPixelFormat, allocator: std.mem.Allocator) void {
    _ = allocator;

    self.* = undefined;
}
