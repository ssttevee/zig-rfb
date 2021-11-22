const std = @import("std");

const Bell = @This();

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader) !Bell {
    _ = allocator;
    _ = r;

    return .{};
}

pub fn write(self: *const Bell, w: *std.Io.Writer) !void {
    _ = self;
    _ = w;
}

pub fn deinit(self: *Bell, allocator: std.mem.Allocator) void {
    _ = allocator;

    self.* = undefined;
}
