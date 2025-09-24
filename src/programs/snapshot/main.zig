const std = @import("std");
const rfb = @import("rfb");

fn printHelp(program: []const u8) void {
    std.log.info("Usage: {s} <address>", .{program});
    std.log.info("", .{});
    std.log.info("Example: {s} 127.0.0.1", .{program});
    std.log.info("         {s} 127.0.0.1:5900", .{program});
    std.log.info("", .{});
}

fn parseArgsAndConnect(allocator: std.mem.Allocator) !std.net.Stream {
    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();

    const program = it.next().?;
    const arg = it.next() orelse {
        printHelp(program);
        return error.InvalidArguments;
    };

    if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
        printHelp(program);
        return error.HelpRequested;
    }

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

    const addr = std.net.Address.parseIp(first, port) catch {
        return try std.net.tcpConnectToHost(allocator, first, port);
    };

    return try std.net.tcpConnectToAddress(addr);
}

fn getImage(allocator: std.mem.Allocator) !rfb.Image {
    const stream = try parseArgsAndConnect(allocator);
    defer stream.close();

    var readbuf: [1 << 14]u8 = undefined;
    var writebuf: [1 << 14]u8 = undefined;

    var input = stream.reader(&readbuf);
    var output = stream.writer(&writebuf);

    var conn = blk: {
        var reason: ?[]const u8 = null;
        break :blk rfb.ClientConnection.init(
            allocator,
            input.interface(),
            &output.interface,
            .{},
            handleSecurity,
            null,
            &reason,
        ) catch |err| {
            if (reason) |msg| {
                std.log.err("Failed to connect to server: {s}", .{msg});
            } else {
                std.log.err("Failed to connect to server", .{});
            }

            return err;
        };
    };
    defer conn.deinit();

    std.log.debug("sending framebuffer update request", .{});

    try conn.writeFramebufferUpdateRequestMessage(.{
        .incremental = false,
        .rect = .initPoints(.zero, conn.framebuffer_size),
    });

    while (true) {
        var msg = try conn.readMessage();
        defer msg.deinit(allocator);

        switch (msg) {
            .native => |native| {
                std.log.debug("received message type {d} ({s})", .{ @intFromEnum(native), @tagName(native) });
            },
            .custom => |custom| {
                std.log.debug("received message type {d}", .{custom.type});
            },
        }

        const payload_iterator = blk: {
            switch (msg) {
                else => {},
                .native => |*native| switch (native.*) {
                    else => {},
                    .framebuffer_update => |*fu| {
                        break :blk fu;
                    },
                },
            }

            continue;
        };

        var image = blk: {
            while (try payload_iterator.next()) |*payload| {
                switch (payload.*) {
                    else => {},
                    .native => |*native| switch (native.*) {
                        .raw => |*raw| break :blk try raw.image.clone(allocator),
                    },
                }
            }

            continue;
        };

        errdefer image.deinit(allocator);

        try payload_iterator.drainRemaining();

        return image;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var image = getImage(allocator) catch |err| {
        if (err == error.HelpRequested) {
            return;
        }

        if (err == error.EndOfStream) {
            std.log.info("Connection closed", .{});
            return;
        }

        if (err == error.ReadFailed) {
            std.log.info("Connection reset", .{});
            return;
        }

        return err;
    };
    defer image.deinit(allocator);

    const f = try std.fs.cwd().createFile("image.ppm", .{});
    defer f.close();

    var wbuf: [1 << 14]u8 = undefined;
    var w = f.writer(&wbuf);

    // TODO: write to disk as PPM
    try w.interface.print("P6\n{d} {d}\n255\n", .{ image.rect.w, image.rect.h });
    try image.writeConvert(&w.interface, &.tc24_24be_rgb);
    try w.interface.flush();
}

fn handleSecurity(allocator: std.mem.Allocator, security_types: []rfb.SecurityType, data: ?*anyopaque) !rfb.ClientSecurity {
    _ = allocator;
    _ = data;

    std.log.info("server offered {d} security types:", .{security_types.len});
    for (security_types) |security_type| {
        switch (security_type) {
            .native => |native| {
                std.log.info("\t {d} ({s})", .{ @intFromEnum(native), @tagName(native) });
            },
            .custom => |custom| {
                std.log.info("\t {d}", .{custom});
            },
        }
    }

    return .none;
}
