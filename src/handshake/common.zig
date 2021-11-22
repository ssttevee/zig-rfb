const std = @import("std");
const root = @import("../root.zig");

const Point = root.Point;
const PixelFormat = root.PixelFormat;

inline fn isNumber(c: u8) bool {
    return switch (c) {
        '0'...'9' => true,
        else => false,
    };
}

pub const ProtocolVersion = struct {
    major: u8,
    minor: u8,

    pub const @"3.3" = ProtocolVersion{ .major = 3, .minor = 3 };
    pub const @"3.7" = ProtocolVersion{ .major = 3, .minor = 7 };
    pub const @"3.8" = ProtocolVersion{ .major = 3, .minor = 8 };

    pub fn read(r: *std.Io.Reader) !ProtocolVersion {
        var buf: [12]u8 = undefined;
        try r.readSliceAll(&buf);
        if (!std.mem.eql(u8, buf[0..4], "RFB ")) {
            return error.BadProtocol;
        }

        inline for ([_]comptime_int{ 4, 5, 6, 8, 9, 10 }) |i| {
            if (!isNumber(buf[i])) {
                return error.BadProtocol;
            }
        }

        if (buf[7] != '.' or buf[11] != '\n') {
            return error.BadProtocol;
        }

        return .{
            .major = try std.fmt.parseInt(u8, buf[4..7], 10),
            .minor = try std.fmt.parseInt(u8, buf[8..11], 10),
        };
    }

    pub fn write(self: ProtocolVersion, w: *std.Io.Writer) !void {
        try w.print("RFB {:0>3}.{:0>3}\n", .{ self.major, self.minor });
    }
};

pub const ServerInfo = struct {
    framebuffer_size: Point,
    pixel_format: PixelFormat = .tc24_32le_rgb,
    name: []const u8,

    pub fn deinit(self: *ServerInfo, allocator: std.mem.Allocator) void {
        self.pixel_format.deinit(allocator);
        allocator.free(self.name);
        self.* = undefined;
    }
};

pub const ClientOptions = struct {
    shared: bool = true,
};

pub const SecurityResult = enum(u32) {
    success = 0,
    failure = 1,
    failure_tight = 2,
    _,

    pub fn ok(self: SecurityResult) bool {
        return self == .success;
    }
};
