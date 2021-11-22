const std = @import("std");
const root = @import("../root.zig");

const NativeType = root.NativeSecurityType;
const Type = root.SecurityType;
const TypeInt = root.SecurityTypeInt;

const NoneSecurity = @import("server/01_none.zig");
const VncAuthenticationSecurity = @import("server/02_vnc_authentication.zig");

const server = @This();

pub const Native = union(NativeType) {
    none: NoneSecurity,
    // vnc_authentication: VncAuthenticationSecurity,

    /// Challenge the client to authenticate.
    ///
    /// Returns a payload containing the challenge data.
    ///
    /// `reason_out` is a message to send to the client about an authentication
    /// failure. It is only set if `challenge` returns `error.ChallengeFailed`.
    /// It is allocated by `allocator` and the caller owns the memory if it is
    /// non-null.
    pub fn challenge(self: *const Native, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer, reason_out: *?[]const u8) !NativePayload {
        switch (self.*) {
            inline else => |security, tag| {
                return @unionInit(
                    NativePayload,
                    @tagName(tag),
                    try security.challenge(allocator, input, output, reason_out),
                );
            },
        }
    }

    pub fn deinit(self: *const Native, allocator: std.mem.Allocator) void {
        switch (self.*) {
            inline else => |*security| security.deinit(allocator),
        }
        self.* = undefined;
    }
};

pub const Custom = struct {
    type: TypeInt,
    vtable: *const VTable,

    pub const VTable = struct {
        challenge: *const fn (self: *const Custom, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer, reason_out: *?[]const u8) Security.ChallengeError!?*anyopaque,
        destroy_payload: *const fn (*const Custom, allocator: std.mem.Allocator, data: ?*anyopaque) void,
        destroy: *const fn (*Custom, allocator: std.mem.Allocator) void,
    };

    pub inline fn challenge(self: *const Custom, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer, reason_out: *?[]const u8) !CustomPayload {
        return .{
            .custom_security = self,
            .data = try self.vtable.challenge(self, allocator, input, output, reason_out),
        };
    }

    pub inline fn deinit(self: *Custom, allocator: std.mem.Allocator) void {
        self.vtable.destroy(self, allocator);
    }

    inline fn deinitPayload(self: *const Custom, allocator: std.mem.Allocator, data: ?*anyopaque) void {
        self.vtable.destroy_payload(self, allocator, data);
    }
};

pub const Security = union(enum) {
    native: Security.Native,
    custom: *Security.Custom,

    pub const Native = server.Native;
    pub const Custom = server.Custom;

    pub const Type = server.Type;

    pub const ChallengeError = error{ChallengeFailed} || std.Io.Reader.StreamError;

    pub fn @"type"(self: *const Security) Security.Type {
        return switch (self.*) {
            .native => |msg| .{ .native = msg },
            .custom => |custom| .fromInt(custom.type),
        };
    }

    pub const none = initNative(.{ .none = .{} });

    pub fn initNative(native: Security.Native) Security {
        return .{ .native = native };
    }

    pub fn initCustom(custom: *Security.Custom) Security {
        return .{ .custom = custom };
    }

    pub fn challenge(self: *const Security, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer, reason_out: *?[]const u8) ChallengeError!Payload {
        return switch (self.*) {
            inline else => |security, tag| @unionInit(
                Payload,
                @tagName(tag),
                try security.challenge(allocator, input, output, reason_out),
            ),
        };
    }

    pub fn deinit(self: *Security, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .native => |*native| native.deinit(allocator),
            .custom => |custom| custom.deinit(allocator),
        }
        self.* = undefined;
    }
};

pub const NativePayload = union(NativeType) {
    none: NoneSecurity.Payload,
    // vnc_authentication: VncAuthenticationSecurity.Payload,

    pub fn deinit(self: *NativePayload, allocator: std.mem.Allocator) void {
        switch (self.*) {
            inline else => |*payload| payload.deinit(allocator),
        }
        self.* = undefined;
    }
};

pub const CustomPayload = struct {
    custom_security: *const Custom,
    data: ?*anyopaque,

    pub fn deinit(self: *CustomPayload, allocator: std.mem.Allocator) void {
        self.custom_security.deinitPayload(allocator, self.data);
        self.* = undefined;
    }
};

pub const Payload = union(enum) {
    native: NativePayload,
    custom: CustomPayload,

    pub const Native = NativePayload;
    pub const Custom = CustomPayload;

    pub fn @"type"(self: *const Payload) Security.Type {
        return switch (self.*) {
            .native => |msg| .{ .native = msg },
            .custom => |custom| .fromInt(custom.custom_security.type),
        };
    }

    pub fn deinit(self: *Payload, allocator: std.mem.Allocator) void {
        switch (self.*) {
            inline else => |*payload| payload.deinit(allocator),
        }
        self.* = undefined;
    }
};
