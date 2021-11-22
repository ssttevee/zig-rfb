const std = @import("std");
const net = std.net;

const Allocator = std.mem.Allocator;

const be = @import("./be.zig");
const rfb = @import("../rfb.zig");

const PixelFormat = rfb.PixelFormat;
const SecurityResult = rfb.SecurityResult;
const SecurityType = rfb.SecurityType;
const ServerInit = rfb.ServerInit;

const Stream = struct {
    stream: net.Stream,

    buf: [1024]u8 = undefined,
    
    const Self = @This();

    pub fn reader(self: Self) net.Stream.Reader {
        return self.stream.reader();
    }
    
    pub fn writer(self: Self) net.Stream.Writer {
        return self.stream.writer();
    }

    pub fn read(self: Self, buffer: []u8) !usize {
        var n = try self.stream.read(buffer);
        if (n == 0) {
            return error.EndOfStream;
        }

        return n;
    }

    pub fn write(self: *Self, payload: anytype) !usize {
        const payloadType = @TypeOf(payload);
        const payloadTypeInfo = @typeInfo(payloadType);

        if (switch (payloadTypeInfo) {
            .Pointer => |p| switch (p.size) {
                .Slice => p.child == u8,
                else => switch (@typeInfo(p.child)) {
                    .Array => |a| a.child == u8,
                    else => false,
                },
            },
            else => false,
        }) {
            return self.stream.write(payload);
        }

        const n = be.memcpy(self.buf[0..], payload);
        return self.stream.write(self.buf[0..n]);
    }
};

pub const RFBServer = struct {
    info: ServerInit,
    name: []const u8,
    allocator: *Allocator,
    buf: []u8,

    const Self = @This();

    pub fn init(allocator: *Allocator, info: ServerInit, name: []const u8) !Self {
        std.debug.assert(info.format.bitsPerPixel % 8 == 0);

        return Self{
            .info = info,
            .name = name,
            .allocator = allocator,
            .buf = try allocator.alloc(u8, @as(usize, info.width) * @as(usize, info.height) * @as(usize, info.format.bitsPerPixel / 8)),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buf);
        self.* = undefined;
    }

    fn _connect(self: Self, stream: *Stream) !void {
        var buf: [1024]u8 = undefined;
        var n: usize = undefined;

        // 7.1.1.  ProtocolVersion Handshake
        _ = try stream.write("RFB 003.008\n");

        n = try stream.read(&buf);
        std.debug.print("client wants: {s}\n", .{buf[0..n]});


        // 7.1.2.  Security Handshake
        _ = try stream.write("\x01\x01");

        var wanted = try stream.reader().readByte();
        if (wanted != 1) {
            std.debug.print("invalid security type {}\n", .{buf[0]});
            return;
        }


        // 7.1.3.  SecurityResult Handshake
        _ = try stream.write(SecurityResult.ok);


        // 7.3.1.  ClientInit
        n = try stream.read(&buf);
        if (n < 1) {
            std.debug.print("client init payload too short {}\n", .{n});
            return;
        }

        if (buf[0] != 0) {
            std.debug.print("client wants to share\n", .{});
        } else {
            std.debug.print("client wants exclusive screen\n", .{});
        }


        // 7.3.2.  ServerInit
        n = try stream.write(.{self.info, @intCast(u32, self.name.len), self.name});


        // main loop
        while (true) {
            n = try stream.read(&buf);
            if (n < 1) {
                std.debug.print("received message payload too short {}\n", .{n});
                continue;
            }

            std.debug.print("received message type: {}\n", .{buf[0]});
        }
    }

    pub fn connect(self: Self, stream: net.Stream) !void {
        defer stream.close();

        try self._connect(&.{ .stream = stream });
    }
};
