const std = @import("std");
const rfb = @import("rfb");

fn printHelp(program: []const u8) void {
    std.log.info("Usage: {s} [address]", .{program});
    std.log.info("", .{});
    std.log.info("Example: {s}", .{program});
    std.log.info("         {s} :5900", .{program});
    std.log.info("         {s} 127.0.0.1:5900", .{program});
    std.log.info("", .{});
}

fn parseArgsAndListen(allocator: std.mem.Allocator) !std.net.Server {
    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();

    const program = it.next().?;
    const arg = it.next() orelse ":5900";
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

    const addr = std.net.Address.parseIp(if (first.len > 0) first else "0.0.0.0", port) catch |err| {
        printHelp(program);
        return err;
    };

    return try addr.listen(.{ .reuse_address = true });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var srv = parseArgsAndListen(allocator) catch |err| {
        if (err == error.HelpRequested) {
            return;
        }

        return err;
    };

    std.log.info("Listening on {f}", .{srv.listen_address});

    var conns = std.AutoArrayHashMap(std.Thread, std.net.Stream).init(allocator);
    defer {
        for (conns.values()) |stream| {
            stream.close();
        }

        for (conns.keys()) |thread| {
            thread.join();
        }

        conns.deinit();
    }

    const server_info = rfb.ServerInfo{
        .framebuffer_size = .{ .x = 800, .y = 600 },
        .name = "demoserver",
    };

    while (true) {
        const conn = try srv.accept();
        std.log.info("Accepted connection from {f}", .{conn.address});
        try conns.put(
            try std.Thread.spawn(.{}, handleConnection, .{ conn, &server_info }),
            conn.stream,
        );
    }
}

fn hsvToRgb(h: f32, s: f32, v: f32) rfb.Color {
    std.debug.assert(h >= 0.0 and h <= 1.0);
    std.debug.assert(s >= 0.0 and s <= 1.0);
    std.debug.assert(v >= 0.0 and v <= 1.0);

    const vv: u16 = @intFromFloat(v * 65535);
    const hh = (h - @floor(h)) * 6;
    const hi: u3 = @intFromFloat(hh);
    const f = hh - @floor(hh);
    const p: u16 = @intFromFloat(v * (@as(f32, 1) - s) * 65535);
    const q: u16 = @intFromFloat(v * (@as(f32, 1) - s * f) * 65535);
    const t: u16 = @intFromFloat(v * (@as(f32, 1) - s * (1 - f)) * 65535);

    return switch (hi) {
        0 => .{ .r = vv, .g = t, .b = p },
        1 => .{ .r = q, .g = vv, .b = p },
        2 => .{ .r = p, .g = vv, .b = t },
        3 => .{ .r = p, .g = q, .b = vv },
        4 => .{ .r = t, .g = p, .b = vv },
        5 => .{ .r = vv, .g = p, .b = q },
        else => unreachable,
    };
}

const PALETTE_SIZE = 256;

fn generatePalette(allocator: std.mem.Allocator, pixel_format: *const rfb.PixelFormat) ![]const u8 {
    const bpp = pixel_format.bytesPerPixel();
    const palette = try allocator.alloc(u8, PALETTE_SIZE * bpp);
    errdefer allocator.free(palette);

    inline for (0..PALETTE_SIZE) |i| {
        _ = pixel_format.packBuf(hsvToRgb(@as(f32, @floatFromInt(i)) / PALETTE_SIZE, 0.2, 0.7), palette[i * bpp ..]) catch unreachable;
    }

    return palette;
}

const Symbols = struct {
    x: f32,
    y: f32,
};

const Symbol = std.meta.FieldEnum(Symbols);

const Operand = union(enum) {
    symbol: Symbol,
    constant: f32,
    expression: *InnerExpression,

    fn random(allocator: std.mem.Allocator, rng: std.Random, allow_constant: bool) std.mem.Allocator.Error!Operand {
        var tag = rng.enumValue(std.meta.Tag(Operand));
        while (tag == .constant and !allow_constant) {
            tag = rng.enumValue(std.meta.Tag(Operand));
        }
        return switch (tag) {
            .symbol => .{ .symbol = rng.enumValue(Symbol) },
            .constant => .{ .constant = rng.float(f32) * 32 },
            .expression => blk: {
                const expr = try allocator.create(InnerExpression);
                errdefer allocator.destroy(expr);
                expr.* = try .random(allocator, rng, allow_constant);
                break :blk .{ .expression = expr };
            },
        };
    }

    fn evaluate(self: *const Operand, symbols: Symbols) f32 {
        return switch (self.*) {
            .symbol => |symbol| switch (symbol) {
                inline else => |tag| @field(symbols, @tagName(tag)),
            },
            .constant => |constant| constant,
            .expression => |expr| expr.evaluate(symbols),
        };
    }

    fn deinit(self: *Operand, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .expression => |expr| {
                expr.deinit(allocator);
                allocator.destroy(expr);
            },
            else => {},
        }
        self.* = undefined;
    }

    pub fn format(self: *const Operand, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try switch (self.*) {
            .symbol => |symbol| w.print("{s}", .{@tagName(symbol)}),
            .constant => |constant| w.print("{d}", .{constant}),
            .expression => |expr| w.print("{f}", .{expr}),
        };
    }

    pub fn hasSymbol(self: *const Operand) bool {
        return switch (self.*) {
            .symbol => true,
            .expression => |expr| expr.hasSymbol(),
            else => false,
        };
    }
};

const InnerExpression = union(enum) {
    identity: Operand,
    // sqrt: Operand,
    add: [2]Operand,
    subtract: [2]Operand,
    multiply: [2]Operand,
    divide: [2]Operand,
    // modulos: [2]Operand,

    fn random(allocator: std.mem.Allocator, rng: std.Random, allow_constant: bool) std.mem.Allocator.Error!InnerExpression {
        return switch (rng.enumValue(std.meta.Tag(InnerExpression))) {
            inline .identity => |tag| @unionInit(
                InnerExpression,
                @tagName(tag),
                try .random(allocator, rng, false),
            ),
            inline else => |tag| blk: {
                var lhs = try Operand.random(allocator, rng, allow_constant);
                errdefer lhs.deinit(allocator);

                break :blk @unionInit(
                    InnerExpression,
                    @tagName(tag),
                    .{
                        lhs,
                        try .random(allocator, rng, true),
                    },
                );
            },
        };
    }

    fn evaluate(self: *const InnerExpression, symbols: Symbols) f32 {
        return switch (self.*) {
            .identity => |operand| operand.evaluate(symbols),
            // .sqrt => |operand| @sqrt(operand.evaluate(symbols)),
            .add => |operands| operands[0].evaluate(symbols) + operands[1].evaluate(symbols),
            .subtract => |operands| operands[0].evaluate(symbols) - operands[1].evaluate(symbols),
            .multiply => |operands| operands[0].evaluate(symbols) * operands[1].evaluate(symbols),
            .divide => |operands| operands[0].evaluate(symbols) / operands[1].evaluate(symbols),
            // .modulos => |operands| @mod(operands[0].evaluate(symbols), operands[1].evaluate(symbols)),
        };
    }

    fn deinit(self: *InnerExpression, allocator: std.mem.Allocator) void {
        switch (self.*) {
            inline .identity => |*operand| operand.deinit(allocator),
            inline else => |*operands| {
                inline for (0..operands.*.len) |i| {
                    operands.*[i].deinit(allocator);
                }
            },
        }
        self.* = undefined;
    }

    pub fn format(self: *const InnerExpression, w: *std.Io.Writer) std.Io.Writer.Error!void {
        return switch (self.*) {
            .identity => |operand| w.print("{f}", .{operand}),
            // .sqrt => |operand| w.print("sqrt({f})", .{operand}),
            .add => |operands| w.print("({f} + {f})", .{ operands[0], operands[1] }),
            .subtract => |operands| w.print("({f} - {f})", .{ operands[0], operands[1] }),
            .multiply => |operands| w.print("({f} * {f})", .{ operands[0], operands[1] }),
            .divide => |operands| w.print("({f} / {f})", .{ operands[0], operands[1] }),
            // .modulos => |operands| w.print("({f} % {f})", .{ operands[0], operands[1] }),
        };
    }

    pub fn hasSymbol(self: *const InnerExpression) bool {
        return switch (self.*) {
            inline .identity => |operand| operand.hasSymbol(),
            inline else => |operands| {
                inline for (operands) |operand| if (operand.hasSymbol()) return true;
            },
        };
    }
};

const Expression = union(enum) {
    sin: InnerExpression,
    cos: InnerExpression,

    fn random(allocator: std.mem.Allocator, rng: std.Random) !Expression {
        return switch (rng.enumValue(std.meta.Tag(Expression))) {
            inline else => |tag| @unionInit(
                Expression,
                @tagName(tag),
                try .random(allocator, rng, false),
            ),
        };
    }

    fn evaluate(self: *const Expression, symbols: Symbols) f32 {
        return switch (self.*) {
            .sin => |expr| @sin(expr.evaluate(symbols)),
            .cos => |expr| @cos(expr.evaluate(symbols)),
        };
    }

    fn deinit(self: *Expression, allocator: std.mem.Allocator) void {
        switch (self.*) {
            inline else => |*expr| expr.deinit(allocator),
        }
        self.* = undefined;
    }

    pub fn format(self: *const Expression, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try switch (self.*) {
            .sin => |expr| w.print("sin({f})", .{expr}),
            .cos => |expr| w.print("cos({f})", .{expr}),
        };
    }
};

const ProceduralPlasma = struct {
    size: rfb.Point,
    plasma: []std.math.IntFittingRange(0, PALETTE_SIZE - 1),
    exprBuf: [4]Expression = undefined,

    fn init(allocator: std.mem.Allocator, size: rfb.Point) !ProceduralPlasma {
        return .{
            .size = size,
            .plasma = try allocator.alloc(std.math.IntFittingRange(0, PALETTE_SIZE - 1), size.x * size.y * 4),
        };
    }

    fn evaluateExprs(exprs: []const Expression, symbols: Symbols) f32 {
        var result: f32 = 0;
        for (exprs) |expr| result += expr.evaluate(symbols);
        // best effort to stay within range of [0, 1]
        return (result / @as(f32, @floatFromInt(exprs.len)) + 1) / 2;
    }

    fn randomizeExprs(allocator: std.mem.Allocator, rng: std.Random, buf: []Expression) ![]Expression {
        const n = rng.intRangeAtMost(usize, 2, buf.len);

        var i: usize = 0;
        errdefer {
            for (buf[0..i]) |*expr| {
                expr.deinit(allocator);
            }
        }

        while (i < n) : (i += 1) {
            buf[i] = try Expression.random(allocator, rng);
        }

        return buf[0..n];
    }

    fn deinit(self: *ProceduralPlasma, allocator: std.mem.Allocator) void {
        allocator.free(self.plasma);
        self.* = undefined;
    }

    fn generate(self: *ProceduralPlasma, allocator: std.mem.Allocator, scale: usize, seed: u64) !void {
        const start = std.time.nanoTimestamp();

        var rng: std.Random.DefaultPrng = .init(seed);
        const exprs = try randomizeExprs(allocator, rng.random(), &self.exprBuf);
        defer for (exprs) |*expr| expr.deinit(allocator);

        std.log.info("Generated {} expressions in {}ms", .{ exprs.len, @as(f32, @floatFromInt(std.time.nanoTimestamp() - start)) / 1000000 });
        // std.log.info("{f}", .{self});

        const start2 = std.time.nanoTimestamp();
        const d = std.math.pow(f32, 2, @floatFromInt(@max(1, scale)));
        const w2 = self.size.x * 2;
        const h2 = self.size.y * 2;
        for (0..h2) |y| {
            for (0..w2) |x| {
                self.plasma[y * w2 + x] = @intCast(@as(usize, @intFromFloat(evaluateExprs(exprs, .{
                    .x = @as(f32, @floatFromInt(x)) / d,
                    .y = @as(f32, @floatFromInt(y)) / d,
                }) * PALETTE_SIZE)) % PALETTE_SIZE);
                // plasma[y * size.x + x] = @intFromFloat((@sin(@as(f32, @floatFromInt(x)) / PLASMA_SIZE_CONSTANT) + @sin(@as(f32, @floatFromInt(y)) / PLASMA_SIZE_CONSTANT)) * 64 + 128);
            }
        }
        std.log.info("Plasma generated in {}ms", .{@as(f32, @floatFromInt(std.time.nanoTimestamp() - start2)) / 1000000});
    }

    // pub fn format(self: *const ProceduralPlasma, w: *std.Io.Writer) std.Io.Writer.Error!void {
    //     for (self.expressions, 0..) |expr, i| {
    //         if (i != 0) {
    //             try w.print(" + ", .{});
    //         }
    //         try w.print("{f}", .{&expr});
    //     }
    // }
};

fn connectionLoop(stream: std.net.Stream, server_info: *const rfb.ServerInfo) !void {
    defer stream.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var readbuf: [1 << 14]u8 = undefined;
    var writebuf: [1 << 14]u8 = undefined;

    var input = stream.reader(&readbuf);
    var output = stream.writer(&writebuf);

    var conn = try rfb.ServerConnection.init(
        allocator,
        input.interface(),
        &output.interface,
        server_info.*,
        &.{.none},
        null,
        null,
    );
    defer conn.deinit();

    const size = server_info.framebuffer_size;

    var image = try rfb.Image.init(allocator, size, &conn.pixel_format);
    defer image.deinit(allocator);

    var image_buf: []u8 = @constCast(image.data);

    var palette = try generatePalette(allocator, &conn.pixel_format);
    defer allocator.free(palette);

    var prev_left = false;
    var prev_right = false;
    var pattern_index: usize = 0;
    var origin: rfb.Point = .zero;
    var invert = false;
    var counter: usize = 0;
    var scale: u16 = 5;

    var plasma: ProceduralPlasma = try .init(allocator, size);
    defer plasma.deinit(allocator);

    var should_regenerate = true;

    var start_time = std.time.milliTimestamp();
    var frames: usize = 0;
    var render_nanos: u64 = 0;
    var write_nanos: u64 = 0;
    while (true) {
        const current_time = std.time.milliTimestamp();
        const delta_time = current_time - start_time;
        if (delta_time > 1000) {
            std.log.info("fps: {d:.2}, render time: {d:.2}ms, write time: {d:.2}ms", .{
                @as(f32, @floatFromInt(frames)) * 1000 / @as(f32, @floatFromInt(delta_time)),
                @as(f32, @floatFromInt(render_nanos)) / @as(f32, @floatFromInt(frames)) / 1000000,
                @as(f32, @floatFromInt(write_nanos)) / @as(f32, @floatFromInt(frames)) / 1000000,
            });

            start_time = current_time;
            frames = 0;
            render_nanos = 0;
            write_nanos = 0;
        }

        blk: {
            var msg = try conn.readMessage();
            defer msg.deinit(allocator);

            switch (msg) {
                else => {},
                .native => |native| switch (native) {
                    else => {},
                    .set_pixel_format => {
                        allocator.free(palette);
                        palette = try generatePalette(allocator, &conn.pixel_format);
                        image.deinit(allocator);
                        image = try .init(allocator, size, &conn.pixel_format);
                        image_buf = @constCast(image.data);
                    },
                    .framebuffer_update_request => {
                        break :blk;
                    },
                    .key_event => |ke| {
                        if (ke.down) {
                            invert = true;
                        }
                    },
                    .pointer_event => |pe| {
                        const left = pe.button_state.isSet(0);
                        const right = pe.button_state.isSet(2);

                        const left_down = prev_left != left and left;
                        const right_down = prev_right != right and right;

                        prev_left = left;
                        prev_right = right;

                        if (!should_regenerate) {
                            inner: {
                                if (left_down and !right) {
                                    pattern_index += 1;
                                } else if (!left and right_down) {
                                    pattern_index -= 1;
                                } else {
                                    break :inner;
                                }

                                // try plasma.generate(allocator, scale, pattern_index);
                                should_regenerate = true;
                            }

                            if (pe.button_state.isSet(3) and scale < 256) {
                                // scroll up
                                scale += 1;
                                std.log.debug("scale up to {}", .{scale});
                                should_regenerate = true;
                            } else if (pe.button_state.isSet(4) and scale > 2) {
                                // scroll down
                                scale -= 1;
                                std.log.debug("scale down to {}", .{scale});
                                should_regenerate = true;
                            }
                        }

                        origin = pe.position;
                    },
                },
            }
            continue;
        }

        if (should_regenerate) {
            try plasma.generate(allocator, scale, pattern_index);
            should_regenerate = false;
        }

        const frame_start_time = std.time.nanoTimestamp();

        const bpp = conn.pixel_format.bytesPerPixel();

        var image_offset: usize = 0;
        for (0..size.y) |y| {
            // const image_offset = y * size.x;
            var plasma_offset = (y + size.y - origin.y) * size.x * 2 + size.x - origin.x;
            for (0..size.x) |_| {
                // const image_index = image_offset + x;
                const palette_index = ((@as(usize, plasma.plasma[plasma_offset]) + counter) % PALETTE_SIZE) * bpp;
                @memcpy(
                    image_buf[image_offset .. image_offset + bpp],
                    palette[palette_index .. palette_index + bpp],
                );

                image_offset += bpp;
                plasma_offset += 1;
            }
        }

        render_nanos += @intCast(std.time.nanoTimestamp() - frame_start_time);

        const write_start_time = std.time.nanoTimestamp();
        try conn.writeRawFrame(&image);
        write_nanos += @intCast(std.time.nanoTimestamp() - write_start_time);

        counter += 1;
        frames += 1;
    }
}

fn handleConnection(conn: std.net.Server.Connection, server_info: *const rfb.ServerInfo) !void {
    connectionLoop(conn.stream, server_info) catch |err| {
        if (err == error.EndOfStream) {
            std.log.info("Connection closed ({f})", .{conn.address});
            return;
        }

        if (err == error.ReadFailed or err == error.WriteFailed) {
            std.log.info("Connection reset", .{});
            return;
        }

        return err;
    };
}
