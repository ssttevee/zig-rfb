const std = @import("std");
const root = @import("../root.zig");

const common = @import("common.zig");

const SecurityType = root.SecurityType;
const ServerSecurity = root.ServerSecurity;
const ServerSecurityPayload = root.ServerSecurityPayload;
const ProtocolVersion = common.ProtocolVersion;
const ServerInfo = common.ServerInfo;
const ClientOptions = common.ClientOptions;
const SecurityResult = common.SecurityResult;

pub fn handshake(
    allocator: std.mem.Allocator,
    input: *std.Io.Reader,
    output: *std.Io.Writer,
    security_candidates: []const ServerSecurity,
) !struct { Initialization, ServerSecurityPayload } {
    std.debug.assert(security_candidates.len > 0);
    std.debug.assert(security_candidates.len < 256);

    try ProtocolVersion.@"3.8".write(output);
    try output.flush();

    const protocol_version = try ProtocolVersion.read(input);
    if (protocol_version.major != 3 or switch (protocol_version.minor) {
        3, 7, 8 => false,
        else => true,
    }) {
        return error.UnsupportedProtocolVersion;
    }

    var security: ServerSecurity = undefined;
    switch (protocol_version.minor) {
        else => unreachable,
        3 => {
            // protocol version 3.3 doesn't allow the client to choose
            // the security type

            try output.writeInt(u32, security_candidates[0].type().toInt(), .big);
            try output.flush();

            security = security_candidates[0];
        },
        7, 8 => {
            try output.writeByte(@truncate(security_candidates.len));
            for (security_candidates) |st| {
                try output.writeByte(st.type().toInt());
            }
            try output.flush();

            const security_type_byte = try input.takeByte();

            if (blk: {
                for (security_candidates) |candidate| {
                    if (security_type_byte == @as(u8, candidate.type().toInt())) {
                        break :blk @as(?ServerSecurity, candidate);
                    }
                }

                break :blk @as(?ServerSecurity, null);
            }) |found_security_type| {
                security = found_security_type;
            } else {
                // the client asked for a security type that was not offered
                const reason = "invalid security type";

                blk: {
                    // send reason on best effort basis
                    output.writeInt(u32, @truncate(reason.len), .big) catch break :blk;
                    output.writeAll(reason) catch break :blk;
                    output.flush() catch {};
                }

                return error.ClientFailure;
            }
        },
    }

    var reason: ?[]const u8 = null;
    defer if (reason) |msg| allocator.free(msg);

    const security_payload = security.challenge(allocator, input, output, &reason) catch |err| {
        if (err == error.ChallengeFailed) {
            sendSecurityFailure(protocol_version, output, reason orelse "bad response") catch {
                // ignore this error since the connection should be closed after this anyways
            };
            return error.SecurityFailure;
        }

        return err;
    };

    return .{
        .{ .protocol_version = protocol_version },
        security_payload,
    };
}

fn sendSecurityFailure(protocol_version: ProtocolVersion, output: *std.Io.Writer, reason: []const u8) !void {
    try output.writeInt(u32, @intFromEnum(SecurityResult.failure), .big);
    switch (protocol_version.minor) {
        else => {},
        8 => {
            try writeString(output, reason);
        },
    }

    try output.flush();
}

pub const Initialization = struct {
    protocol_version: ProtocolVersion,

    pub fn next(self: *const Initialization, input: *std.Io.Reader, output: *std.Io.Writer, server_info: ServerInfo) !ClientOptions {
        _ = self;

        try output.writeInt(u32, @intFromEnum(SecurityResult.success), .big);
        try output.flush();

        const shared = (try input.takeByte()) != 0;

        try output.writeInt(u16, @truncate(server_info.framebuffer_size.x), .big);
        try output.writeInt(u16, @truncate(server_info.framebuffer_size.y), .big);
        try server_info.pixel_format.write(output);
        try writeString(output, server_info.name);
        try output.flush();

        return .{
            .shared = shared,
        };
    }

    pub inline fn reject(self: *const Initialization, output: *std.Io.Writer, reason: []const u8) !void {
        try sendSecurityFailure(self.protocol_version, output, reason);
    }
};

pub fn writeString(w: *std.Io.Writer, str: []const u8) !void {
    try w.writeInt(u32, @truncate(str.len), .big);
    try w.writeAll(str);
}
