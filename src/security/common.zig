const std = @import("std");

pub const SecurityTypeInt = u8;

pub const NativeSecurityType = enum(SecurityTypeInt) {
    none = 1,
    // vnc_authentication = 2,
};

pub const SecurityType = union(enum) {
    native: NativeSecurityType,
    custom: SecurityTypeInt,

    pub const Int = SecurityTypeInt;

    pub const none = fromEnum(.none);
    // pub const vnc_authentication = fromEnum(.vnc_authentication);

    pub fn fromEnum(value: NativeSecurityType) SecurityType {
        return .{ .native = value };
    }

    pub fn fromInt(value: SecurityTypeInt) SecurityType {
        if (std.enums.fromInt(NativeSecurityType, value)) |native| {
            return .{ .native = native };
        }

        return .{ .custom = value };
    }

    pub fn toInt(self: SecurityType) SecurityTypeInt {
        return switch (self) {
            .native => |native| @intFromEnum(native),
            .custom => |custom| custom,
        };
    }

    pub fn eql(self: SecurityType, other: SecurityType) bool {
        return self.toInt() == other.toInt();
    }
};
