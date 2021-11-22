const std = @import("std");
const root = @import("../root.zig");

const common = @import("common.zig");

const ClientSecurity = root.ClientSecurity;
const NativeSecurityType = root.NativeSecurityType;
const SecurityType = root.SecurityType;
const Point = root.Point;
const PixelFormat = root.PixelFormat;
const ProtocolVersion = common.ProtocolVersion;
const ServerInfo = common.ServerInfo;
const ClientOptions = common.ClientOptions;
const SecurityResult = common.SecurityResult;

pub fn handshake(allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer, reason_out: ?*?[]const u8) !struct { SecurityChallenge, []SecurityType } {
    const protocol_version = try ProtocolVersion.read(input);

    if (protocol_version.major != 3 or switch (protocol_version.minor) {
        3, 7, 8 => false,
        else => true,
    }) {
        std.log.info("ProtocolVersion: {any}", .{protocol_version});
        return error.UnsupportedProtocolVersion;
    }

    try protocol_version.write(output);
    try output.flush();

    outer: {
        return .{
            .{ .protocol_version = protocol_version },
            blk: {
                switch (protocol_version.minor) {
                    else => unreachable,
                    3 => {
                        const security_type = try input.takeInt(u32, .big);
                        if (security_type == 0) {
                            break :outer;
                        }
                        break :blk try allocator.dupe(
                            SecurityType,
                            &.{
                                .fromInt(@truncate(security_type)),
                            },
                        );
                    },
                    7, 8 => {
                        const number_of_security_types = try input.takeByte();
                        if (number_of_security_types == 0) {
                            break :outer;
                        }
                        const security_types = try allocator.alloc(SecurityType, number_of_security_types);
                        errdefer allocator.free(security_types);
                        for (0..number_of_security_types) |i| {
                            const security_type_value = try input.takeByte();
                            if (security_type_value == 0) {
                                return error.ServerSentInvalidSecurityType;
                            }
                            security_types[i] = .fromInt(security_type_value);
                        }
                        break :blk security_types;
                    },
                }
            },
        };
    }

    try readOrDiscardString(allocator, input, reason_out);

    return error.ServerFailure;
}

pub const SecurityChallenge = struct {
    protocol_version: ProtocolVersion,

    /// Performs the security challenge and, if security challenge is passed,
    /// the initialization.
    ///
    /// `reason_out` is an optional pointer to get the failure reason if it is
    /// sent by the server. It is allocated by `allocator` and the caller owns
    /// the memory if it is non-null.
    pub fn next(self: SecurityChallenge, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer, security: ClientSecurity, options: ClientOptions, reason_out: ?*?[]const u8) !ServerInfo {
        switch (self.protocol_version.minor) {
            else => {
                // do nothing
            },
            7, 8 => {
                try output.writeByte(security.type().toInt());
                try output.flush();
            },
        }

        try security.authenticate(allocator, input, output);

        const status = try input.takeEnumNonexhaustive(SecurityResult, .big);
        if (!status.ok()) {
            switch (self.protocol_version.minor) {
                else => {
                    // connection should've been closed by the server
                },
                8 => {
                    try readOrDiscardString(allocator, input, reason_out);
                },
            }

            return error.ChallengeFailed;
        }

        try output.writeByte(if (options.shared) 1 else 0);
        try output.flush();

        const size = Point{
            .x = try input.takeInt(u16, .big),
            .y = try input.takeInt(u16, .big),
        };
        const pixel_format = try PixelFormat.read(input);
        return .{
            .framebuffer_size = size,
            .pixel_format = pixel_format,
            .name = try input.readAlloc(allocator, try input.takeInt(u32, .big)),
        };
    }
};

pub fn readOrDiscardString(allocator: std.mem.Allocator, r: *std.Io.Reader, out_ptr: ?*?[]const u8) !void {
    const len = try r.takeInt(u32, .big);
    if (out_ptr) |out| {
        out.* = try r.readAlloc(allocator, len);
    } else {
        try r.discardAll(len);
    }
}
