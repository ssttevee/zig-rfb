const std = @import("std");
const rfb = @import("rfb");

fn printHelp(program: []const u8) void {
    std.log.info("Usage: {s} <client|server> [ip:port]", .{program});
    std.log.info("", .{});
    std.log.info("Example: {s} client 127.0.0.1:5900", .{program});
    std.log.info("         {s} server 127.0.0.1:5900", .{program});
    std.log.info("", .{});
}

const Side = enum(u1) {
    client,
    server,

    fn Message(comptime self: Side) type {
        return @field(rfb, @tagName(self)).Message;
    }

    fn other(self: Side) Side {
        return switch (self) {
            .client => .server,
            .server => .client,
        };
    }
};

fn parseArgsAddress(allocator: std.mem.Allocator) !struct { Side, std.net.Address } {
    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();

    const program = it.next().?;
    const side = blk: {
        const arg = it.next() orelse {
            printHelp(program);
            return error.HelpRequested;
        };

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printHelp(program);
            return error.HelpRequested;
        }

        break :blk std.meta.stringToEnum(Side, arg) orelse {
            std.log.err("Invalid mode: {s}", .{arg});
            printHelp(program);
            return error.InvalidMode;
        };
    };

    const arg = it.next() orelse "127.0.0.1:5900";
    const first, const rest = blk: {
        var split = std.mem.splitScalar(u8, arg[0..std.mem.len(arg.ptr)], ':');
        break :blk .{ split.first(), split.rest() };
    };

    var port: u16 = 5900;
    if (rest.len > 0) {
        port = std.fmt.parseInt(u16, rest, 10) catch {
            std.log.err("Invalid port number: {s}", .{rest});
            return error.InvalidPort;
        };
    }

    return .{
        side,
        std.net.Address.parseIp(if (first.len > 0) first else "0.0.0.0", port) catch |err| {
            printHelp(program);
            return err;
        },
    };
}

const text_chat_message_id = 11;

fn TextChatCustomMessage(comptime side: Side) type {
    const Message = side.Message();
    return struct {
        const Self = @This();

        text: []const u8 = &.{},
        interface: Message.Custom = .{
            .type = text_chat_message_id,
            .vtable = &.{
                .write = switch (side) {
                    .client => clientWriteFn,
                    .server => serverWriteFn,
                },
                .destroy = destroyFn,
            },
        },

        fn clientWriteFn(interface: *const Message.Custom, w: *std.Io.Writer) Message.Custom.WriteError!void {
            const self: *const Self = @fieldParentPtr("interface", interface);
            try w.writeInt(u32, @intCast(self.text.len), .big);
            try w.writeAll(self.text);
        }

        fn serverWriteFn(interface: *const Message.Custom, w: *std.Io.Writer, pixel_format: *const rfb.PixelFormat) !void {
            _ = pixel_format;

            try clientWriteFn(interface, w);
        }

        fn destroyFn(interface: *Message.Custom, allocator: std.mem.Allocator) void {
            const self: *Self = @fieldParentPtr("interface", interface);
            allocator.free(self.text);
        }
    };
}

fn startChat(allocator: std.mem.Allocator, stream: std.net.Stream, comptime side: Side) !void {
    var readbuf: [1 << 14]u8 = undefined;
    var writebuf: [1 << 14]u8 = undefined;

    var input = stream.reader(&readbuf);
    var output = stream.writer(&writebuf);

    switch (side) {
        .client => {
            var reason: ?[]const u8 = null;
            defer if (reason) |s| allocator.free(s);

            const step, const security_types = rfb.clientHandshake(allocator, input.interface(), &output.interface, &reason) catch |err| {
                if (reason) |s| {
                    std.log.err("Failed to connect to server: {s}", .{s});
                } else {
                    std.log.err("Failed to connect to server", .{});
                }

                return err;
            };

            // don't even look at the options lol
            allocator.free(security_types);

            var server_info = step.next(allocator, input.interface(), &output.interface, .none, .{}, &reason) catch |err| {
                if (reason) |s| {
                    std.log.err("Failed to connect to server: {s}", .{s});
                } else {
                    std.log.err("Failed to connect to server", .{});
                }

                return err;
            };
            defer server_info.deinit(allocator);

            std.log.info("Handshake with {s} successful", .{server_info.name});
        },
        .server => {
            const step, var security_payload = try rfb.serverHandshake(allocator, input.interface(), &output.interface, &.{.none});
            security_payload.deinit(allocator);

            _ = try step.next(input.interface(), &output.interface, .{
                .framebuffer_size = .zero,
                .name = "chatterbox demo",
            });

            std.log.info("Handshake successful", .{});
        },
    }

    var exited: std.atomic.Value(bool) = .init(false);

    const t = try std.Thread.spawn(.{}, wrapLoop, .{ readLoop, .{ comptime side.other(), input.interface() }, stream, &exited });
    defer t.join();

    try wrapLoop(writeLoop, .{ side, &output.interface }, stream, &exited);
}

const MAX_CHAT_LENGTH = 1 << 14;

fn TextChatMessageHandlerContext(comptime side: Side) type {
    return struct {
        msg: TextChatCustomMessage(side) = .{},
        text_buf: [MAX_CHAT_LENGTH]u8 = undefined,
    };
}

fn textChatMessageHandler(comptime side: Side) side.Message().CustomHandlerFn {
    const Message = side.Message();
    return struct {
        fn clientReadHandler(
            allocator: std.mem.Allocator,
            r: *std.Io.Reader,
            message_type: Message.Type.Int,
            data: ?*anyopaque,
        ) Message.Custom.ReadError!?*Message.Custom {
            _ = allocator;

            if (message_type == text_chat_message_id) {
                const self: *TextChatMessageHandlerContext(side) = @ptrCast(@alignCast(data));
                const message_length = try r.takeInt(u32, .big);
                const buf = self.text_buf[0..message_length];
                try r.readSliceAll(buf);
                self.msg.text = buf;
                return &self.msg.interface;
            }

            return null;
        }

        fn serverReadHandler(
            allocator: std.mem.Allocator,
            r: *std.Io.Reader,
            pixel_format: *const rfb.PixelFormat,
            message_type: Message.Type.Int,
            data: ?*anyopaque,
        ) !?*Message.Custom {
            _ = pixel_format;

            return try clientReadHandler(allocator, r, message_type, data);
        }

        const readHandler = switch (side) {
            .client => clientReadHandler,
            .server => serverReadHandler,
        };
    }.readHandler;
}

fn readLoop(comptime side: Side, r: *std.Io.Reader) !void {
    var data: TextChatMessageHandlerContext(side) = .{};

    // create an allocator that always fails since the text chat message implementation uses the global buffer
    var buf: [0]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    while (true) {
        var msg = try @call(
            .auto,
            side.Message().read,
            .{ allocator, r } ++
                (if (side == .server) .{&rfb.PixelFormat.default} else .{}) ++
                .{ textChatMessageHandler(side), &data } ++
                (if (side == .server) .{ null, null } else .{}),
        );

        // don't need to deinit because it is allocated on the stack

        switch (msg) {
            .custom => |custom| {
                std.debug.assert(custom == &data.msg.interface);
                std.debug.print("{s}: {s}\n", .{ @tagName(side.other()), data.msg.text });
            },
            else => {
                std.debug.panic("unexpected message type: {d}", .{msg.type().toInt()});
            },
        }
    }
}

fn writeLoop(comptime side: Side, w: *std.Io.Writer) !void {
    var msgTextBuf: [MAX_CHAT_LENGTH]u8 = undefined;
    var data: TextChatCustomMessage(side) = .{};

    const f = std.fs.File.stdin();
    defer f.close();

    var reader = f.reader(&msgTextBuf);

    var msg: side.Message() = .initCustom(&data.interface);

    while (true) {
        data.text = try reader.interface.takeDelimiterExclusive('\n');

        try @call(
            .auto,
            side.Message().write,
            .{ &msg, w } ++
                (if (side == .server) .{
                    // the pixel format here doesn't really matter since text chat doesn't need it
                    &rfb.PixelFormat.default,
                } else .{}),
        );

        try w.flush();
    }
}

fn wrapLoop(f: anytype, args: anytype, stream: std.net.Stream, exited: *std.atomic.Value(bool)) !void {
    defer stream.close();

    const result = @call(.auto, f, args);
    if (exited.swap(true, .monotonic)) {
        // already exited
        return;
    }

    result catch |err| {
        if (err == error.EndOfStream) {
            std.log.info("Connection closed", .{});
            return;
        }

        if (err == error.ReadFailed or err == error.WriteFailed) {
            std.log.info("Connection reset", .{});
            return;
        }

        return err;
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const side, const addr = parseArgsAddress(allocator) catch |err| {
        if (err == error.HelpRequested) {
            return;
        }

        return err;
    };

    const stream = switch (side) {
        .client => blk: {
            const stream = try std.net.tcpConnectToAddress(addr);
            std.log.info("Connected to {f}", .{addr});
            break :blk stream;
        },
        .server => blk: {
            var server = try addr.listen(.{ .reuse_address = true });
            defer server.deinit();

            std.log.info("Waiting for connection on {f}", .{server.listen_address});
            const conn = try server.accept();
            std.log.info("Accepted connection from {f}", .{conn.address});

            break :blk conn.stream;
        },
    };

    switch (side) {
        inline else => |tag| try startChat(allocator, stream, tag),
    }
}
