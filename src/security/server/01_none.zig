const std = @import("std");

const NoneSecurity = @This();

pub const Payload = struct {
    pub inline fn deinit(self: *Payload, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

pub inline fn challenge(
    self: *const NoneSecurity,
    allocator: std.mem.Allocator,
    input: *std.Io.Reader,
    output: *std.Io.Writer,
    reason_out: *?[]const u8,
) !Payload {
    _ = self;
    _ = allocator;
    _ = input;
    _ = output;
    _ = reason_out;

    return .{};
}
