const std = @import("std");

const VncAuthenticationSecurity = @This();

password: []const u8,

pub fn authenticate(self: *const VncAuthenticationSecurity, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer) !void {
    std.debug.panic("not implemented", .{});

    _ = allocator;

    var challenge: [16]u8 = undefined;
    try input.readSliceAll(&challenge);

    // TODO encrypt buf with password using std lib when available

    _ = self.password;

    try output.writeAll(&challenge);
    try output.flush();
}

pub inline fn deinit(self: *VncAuthenticationSecurity, allocator: std.mem.Allocator) void {
    allocator.free(self.password);
    self.* = undefined;
}
