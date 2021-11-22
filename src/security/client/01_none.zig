const std = @import("std");

const NoneSecurity = @This();

pub inline fn authenticate(self: *const NoneSecurity, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer) !void {
    _ = self;
    _ = allocator;
    _ = input;
    _ = output;
}

pub inline fn deinit(self: *NoneSecurity, allocator: std.mem.Allocator) void {
    _ = allocator;

    self.* = undefined;
}
