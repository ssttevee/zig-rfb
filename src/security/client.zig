const std = @import("std");
const root = @import("../root.zig");

const client = @This();

const NativeType = root.NativeSecurityType;
const Type = root.SecurityType;
const TypeInt = root.SecurityTypeInt;

pub const Native = union(NativeType) {
    none: @import("client/01_none.zig"),
    // vnc_authentication: @import("client/02_vnc_authentication.zig"),

    pub fn authenticate(self: *const Native, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer) !void {
        switch (self.*) {
            inline else => |security| try security.authenticate(allocator, input, output),
        }
    }

    pub fn deinit(self: *Native, allocator: std.mem.Allocator) void {
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
        authenticate: *const fn (*const Custom, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer) Security.AuthenticateError!void,
        destroy: *const fn (*Custom, allocator: std.mem.Allocator) void,
    };

    pub inline fn authenticate(self: *const Custom, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer) !void {
        return try self.vtable.authenticate(self, allocator, input, output);
    }

    pub inline fn deinit(self: *Custom, allocator: std.mem.Allocator) void {
        self.vtable.destroy(self, allocator);
    }
};

pub const Security = union(enum) {
    native: Security.Native,
    custom: *Security.Custom,

    pub const Native = client.Native;
    pub const Custom = client.Custom;

    pub const Type = client.Type;

    pub const AuthenticateError = error{AuthenticationFailed} || std.Io.Reader.StreamError;

    pub const none = Security{ .native = .{ .none = .{} } };

    pub fn @"type"(self: *const Security) Security.Type {
        return switch (self.*) {
            .native => |msg| .{ .native = msg },
            .custom => |custom| .fromInt(custom.type),
        };
    }

    pub fn authenticate(self: *const Security, allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer) AuthenticateError!void {
        switch (self.*) {
            inline else => |security| try security.authenticate(allocator, input, output),
        }
    }

    pub fn deinit(self: *Security, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .native => |*native| native.deinit(allocator),
            .custom => |custom| custom.deinit(allocator),
        }
        self.* = undefined;
    }
};
