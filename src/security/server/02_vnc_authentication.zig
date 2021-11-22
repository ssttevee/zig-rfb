const std = @import("std");

const VncAuthenticationSecurity = @This();

random: *std.Io.Reader,
password: []const u8,

pub const Payload = struct {
    pub inline fn deinit(self: *Payload, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

pub fn challenge(
    self: *const VncAuthenticationSecurity,
    allocator: std.mem.Allocator,
    input: *std.Io.Reader,
    output: *std.Io.Writer,
    reason_out: *?[]const u8,
) !Payload {
    std.debug.panic("not implemented", .{});

    var buf: [16]u8 = undefined;
    try self.random.readSliceAll(&buf);
    try output.writeAll(&buf);
    try output.flush();

    var response: [16]u8 = undefined;
    try input.readSliceAll(&response);

    // TODO encrypt buf with password using std lib when available

    if (!std.mem.eql(buf, response)) {
        pass: {
            reason_out.* = allocator.dupe(u8, "bad response") catch break :pass;
        }

        return error.ChallengeFailed;
    }

    return .{};
}
