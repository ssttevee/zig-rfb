const std = @import("std");
const root = @import("root.zig");

const ConstRc = @import("rc.zig").ConstRc;

const ColorMap = root.ColorMap;
const Color = root.Color;

pub const TrueColorPixelFormat = struct {
    bits_per_pixel: u8,
    depth: u8,
    big_endian: bool,

    red_max: u16,
    green_max: u16,
    blue_max: u16,

    red_shift: u8,
    green_shift: u8,
    blue_shift: u8,
};

pub const ColorMapPixelFormat = struct {
    bits_per_pixel: u8,
    depth: u8,
    big_endian: bool,

    color_map: ?ConstRc(ColorMap) = null,
};

pub const PixelFormat = union(enum) {
    true_color: TrueColorPixelFormat,
    color_map: ColorMapPixelFormat,

    pub const default = tc24_32le_rgb;

    pub const tc24_32le_rgb = PixelFormat{
        .true_color = .{
            .bits_per_pixel = 32,
            .depth = 24,
            .big_endian = false,
            .red_max = 255,
            .green_max = 255,
            .blue_max = 255,
            .red_shift = 16,
            .green_shift = 8,
            .blue_shift = 0,
        },
    };

    pub const tc24_32le_bgr = PixelFormat{
        .true_color = .{
            .bits_per_pixel = 32,
            .depth = 24,
            .big_endian = false,
            .red_max = 255,
            .green_max = 255,
            .blue_max = 255,
            .red_shift = 0,
            .green_shift = 8,
            .blue_shift = 16,
        },
    };

    pub const tc24_32be_rgb = PixelFormat{
        .true_color = .{
            .bits_per_pixel = 32,
            .depth = 24,
            .big_endian = true,
            .red_max = 255,
            .green_max = 255,
            .blue_max = 255,
            .red_shift = 16,
            .green_shift = 8,
            .blue_shift = 0,
        },
    };

    pub const tc24_32be_bgr = PixelFormat{
        .true_color = .{
            .bits_per_pixel = 32,
            .depth = 24,
            .big_endian = true,
            .red_max = 255,
            .green_max = 255,
            .blue_max = 255,
            .red_shift = 0,
            .green_shift = 8,
            .blue_shift = 16,
        },
    };

    pub const tc24_24le_rgb = PixelFormat{
        .true_color = .{
            .bits_per_pixel = 24,
            .depth = 24,
            .big_endian = false,
            .red_max = 255,
            .green_max = 255,
            .blue_max = 255,
            .red_shift = 16,
            .green_shift = 8,
            .blue_shift = 0,
        },
    };

    pub const tc24_24le_bgr = PixelFormat{
        .true_color = .{
            .bits_per_pixel = 24,
            .depth = 24,
            .big_endian = false,
            .red_max = 255,
            .green_max = 255,
            .blue_max = 255,
            .red_shift = 0,
            .green_shift = 8,
            .blue_shift = 16,
        },
    };

    pub const tc24_24be_rgb = PixelFormat{
        .true_color = .{
            .bits_per_pixel = 24,
            .depth = 24,
            .big_endian = true,
            .red_max = 255,
            .green_max = 255,
            .blue_max = 255,
            .red_shift = 16,
            .green_shift = 8,
            .blue_shift = 0,
        },
    };

    pub const tc24_24be_bgr = PixelFormat{
        .true_color = .{
            .bits_per_pixel = 24,
            .depth = 24,
            .big_endian = true,
            .red_max = 255,
            .green_max = 255,
            .blue_max = 255,
            .red_shift = 0,
            .green_shift = 8,
            .blue_shift = 16,
        },
    };

    pub fn read(r: *std.Io.Reader) !PixelFormat {
        var buf: [16]u8 = undefined;
        try r.readSliceAll(&buf);

        const bpp, const d, const be, const tc = buf[0..4].*;

        var out: PixelFormat = undefined;
        if (tc != 0) {
            out = .{
                .true_color = .{
                    .bits_per_pixel = bpp,
                    .depth = d,
                    .big_endian = be != 0,
                    .red_max = std.mem.readInt(u16, buf[4..6], .big),
                    .green_max = std.mem.readInt(u16, buf[6..8], .big),
                    .blue_max = std.mem.readInt(u16, buf[8..10], .big),
                    .red_shift = buf[10],
                    .green_shift = buf[11],
                    .blue_shift = buf[12],
                },
            };
        } else {
            out = .{
                .color_map = .{
                    .bits_per_pixel = bpp,
                    .depth = d,
                    .big_endian = be != 0,
                },
            };
        }

        return out;
    }

    pub fn write(self: *const PixelFormat, w: *std.Io.Writer) !void {
        var buf = std.mem.zeroes([16]u8);

        switch (self.*) {
            .true_color => |tc| {
                buf[0] = tc.bits_per_pixel;
                buf[1] = tc.depth;
                buf[2] = if (tc.big_endian) 1 else 0;
                buf[3] = 1;
                std.mem.writeInt(u16, buf[4..6], tc.red_max, .big);
                std.mem.writeInt(u16, buf[6..8], tc.green_max, .big);
                std.mem.writeInt(u16, buf[8..10], tc.blue_max, .big);
                buf[10] = tc.red_shift;
                buf[11] = tc.green_shift;
                buf[12] = tc.blue_shift;
            },
            .color_map => |cm| {
                buf[0] = cm.bits_per_pixel;
                buf[1] = cm.depth;
                buf[2] = if (cm.big_endian) 1 else 0;
                buf[3] = 0;
            },
        }

        try w.writeAll(&buf);
    }

    pub fn bytesPerPixel(self: *const PixelFormat) usize {
        return (self.bitsPerPixel() + 7) / 8;
    }

    pub fn bitsPerPixel(self: *const PixelFormat) u8 {
        return switch (self.*) {
            .true_color => |tc| tc.bits_per_pixel,
            .color_map => |cm| cm.bits_per_pixel,
        };
    }

    pub fn depth(self: *const PixelFormat) u8 {
        return switch (self.*) {
            .true_color => |tc| tc.depth,
            .color_map => |cm| cm.depth,
        };
    }

    pub fn bigEndian(self: *const PixelFormat) bool {
        return switch (self.*) {
            .true_color => |tc| tc.big_endian,
            .color_map => |cm| cm.big_endian,
        };
    }

    pub fn endian(self: *const PixelFormat) std.builtin.Endian {
        return if (self.bigEndian()) .big else .little;
    }

    pub fn minBytes(self: *const PixelFormat, width: usize, height: usize) usize {
        return self.bytesPerPixel() * width * height;
    }

    pub fn eql(self: *const PixelFormat, other: *const PixelFormat) bool {
        return std.meta.eql(self.*, other.*);
    }

    pub fn unpack(self: *const PixelFormat, buf: []const u8) !Color {
        if (buf.len < self.bytesPerPixel()) {
            return error.NotEnoughData;
        }

        var num: u64 = 0;
        const bytes_per_pixel = self.bytesPerPixel();
        switch (self.endian()) {
            .big => {
                for (0..bytes_per_pixel) |i| {
                    num |= @as(u64, @intCast(buf[i])) << @intCast((bytes_per_pixel - i - 1) * 8);
                }
            },
            .little => {
                for (0..bytes_per_pixel) |i| {
                    num |= @as(u64, @intCast(buf[i])) << @intCast(i * 8);
                }
            },
        }

        switch (self.*) {
            .true_color => |tc| {
                return Color{
                    .r = @truncate(((num >> @truncate(tc.red_shift)) & tc.red_max) * std.math.maxInt(u16) / tc.red_max),
                    .g = @truncate(((num >> @truncate(tc.green_shift)) & tc.green_max) * std.math.maxInt(u16) / tc.green_max),
                    .b = @truncate(((num >> @truncate(tc.blue_shift)) & tc.blue_max) * std.math.maxInt(u16) / tc.blue_max),
                };
            },
            .color_map => |cm| {
                if (cm.color_map) |colors| {
                    if (colors.ptr.getColor(@truncate(num))) |color| {
                        return color;
                    }

                    return Color.black;
                }

                return Color.black;
            },
        }
    }

    pub fn packBuf(self: *const PixelFormat, color: Color, buf: []u8) ![]u8 {
        const bytes_per_pixel = self.bytesPerPixel();
        if (buf.len < bytes_per_pixel) {
            return error.NotEnoughSpace;
        }

        var num: u64 = 0;
        switch (self.*) {
            .true_color => |tc| {
                num |= ((@as(u64, @intCast(color.r)) * tc.red_max / std.math.maxInt(u16)) << @truncate(tc.red_shift));
                num |= ((@as(u64, @intCast(color.g)) * tc.green_max / std.math.maxInt(u16)) << @truncate(tc.green_shift));
                num |= ((@as(u64, @intCast(color.b)) * tc.blue_max / std.math.maxInt(u16)) << @truncate(tc.blue_shift));
            },
            .color_map => |cm| {
                if (cm.color_map) |colors| {
                    if (colors.ptr.getIndex(color)) |index| {
                        num = @truncate(index);
                    } else {
                        // set to first color
                        num = colors.ptr.offset;
                    }
                }
            },
        }

        switch (self.endian()) {
            .big => {
                for (0..bytes_per_pixel) |i| {
                    buf[i] = @truncate(num >> @truncate((bytes_per_pixel - i - 1) * 8));
                }
            },
            .little => {
                for (0..bytes_per_pixel) |i| {
                    buf[i] = @truncate(num >> @truncate(i * 8));
                }
            },
        }

        return buf[0..bytes_per_pixel];
    }

    pub fn convert(self: *const PixelFormat, pixel_bytes: []const u8, new_format: *const PixelFormat, out: []u8) ![]u8 {
        if (self.eql(new_format)) {
            const bytes_per_pixel = self.bytesPerPixel();
            if (pixel_bytes.ptr != out.ptr) {
                @memcpy(out[0..bytes_per_pixel], pixel_bytes[0..bytes_per_pixel]);
            }

            return out[0..bytes_per_pixel];
        }

        return try new_format.packBuf(try self.unpack(pixel_bytes), out);
    }

    pub fn streamConvert(self: *const PixelFormat, r: *std.Io.Reader, w: *std.Io.Writer, new_format: *const PixelFormat, pixel_count: usize) std.Io.Reader.StreamError!void {
        const our_bpp = self.bytesPerPixel();
        if (self.eql(new_format)) {
            _ = try r.stream(w, @enumFromInt(our_bpp * pixel_count));
            return;
        }

        const new_bpp = new_format.bytesPerPixel();

        var read_buf: []u8 = &.{};
        var write_buf: []u8 = &.{};

        var i: usize = 0;
        while (i < pixel_count) {
            while (true) {
                read_buf = r.buffered();
                if (read_buf.len >= our_bpp) break;
                try r.fillMore();
            }

            while (true) {
                write_buf = w.unusedCapacitySlice();
                if (write_buf.len >= new_bpp) break;
                try w.flush();
            }

            const pixels_in_read_buf = read_buf.len / our_bpp;
            read_buf.len = pixels_in_read_buf * our_bpp;

            const pixels_to_write_into_buf = @min(write_buf.len / new_bpp, pixels_in_read_buf);
            write_buf.len = pixels_to_write_into_buf * new_bpp;

            while (write_buf.len > 0) {
                _ = new_format.packBuf(self.unpack(read_buf) catch unreachable, write_buf) catch unreachable;

                r.toss(our_bpp);
                w.advance(new_bpp);

                read_buf = read_buf[our_bpp..];
                write_buf = write_buf[new_bpp..];
            }

            i += pixels_to_write_into_buf;
        }
    }

    pub fn clone(self: *const PixelFormat) PixelFormat {
        switch (self.*) {
            .color_map => |*color_map| if (color_map.color_map) |*cm| {
                _ = cm.ref();
            },
            else => {},
        }
        return self.*;
    }

    pub fn deinit(self: *PixelFormat, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .color_map => |*color_map| if (color_map.color_map) |*cm| cm.deinit(allocator),
            else => {},
        }
        self.* = undefined;
    }

    /// Set the color map if pixel format is color map. Also `deinit` the old
    /// one if it exists.
    ///
    /// Memory ownership of `new_color_map` is not transferred.
    pub fn setColorMap(self: *PixelFormat, allocator: std.mem.Allocator, new_color_map: ColorMap) !void {
        switch (self.*) {
            .color_map => |*pf| {
                if (pf.color_map) |*cm| cm.deinit(allocator);

                var cloned = try new_color_map.clone(allocator);
                errdefer cloned.deinit(allocator);

                pf.color_map = try .init(allocator, cloned);
            },
            else => {
                // not using a color map pixel format...
            },
        }
    }
};

test "pack and unpack" {
    const pf = PixelFormat.tc24_32le_rgb;

    {
        const bytes = [_]u8{ 0x00, 0x00, 0xFF, 0x00 };
        const c = try pf.unpack(&bytes);
        try std.testing.expectEqual(Color{ .r = 0xFFFF, .g = 0, .b = 0 }, c);
        var buf: [4]u8 = undefined;
        const b = try pf.packBuf(c, &buf);
        try std.testing.expectEqualSlices(u8, &bytes, b);
    }
}

test "true color" {
    const buf = [_]u8{
        0x20, // bits per pixel
        0x18, // depth
        0x00, // big endian
        0x01, // true color

        // max
        0x00, 0xFF, // red
        0x00, 0xFF, // green
        0x00, 0xFF, // blue

        // shift
        0x10, // red
        0x08, // green
        0x00, // blue

        // padding
        0x00,
        0x00,
        0x00,
    };

    std.debug.assert(buf.len == 16);

    var r = std.Io.Reader.fixed(&buf);

    const pf = try PixelFormat.read(&r);

    try std.testing.expectEqual(.true_color, std.meta.activeTag(pf));
    try std.testing.expectEqual(32, pf.true_color.bits_per_pixel);
    try std.testing.expectEqual(24, pf.true_color.depth);
    try std.testing.expectEqual(false, pf.true_color.big_endian);
    try std.testing.expectEqual(0x00FF, pf.true_color.red_max);
    try std.testing.expectEqual(0x00FF, pf.true_color.green_max);
    try std.testing.expectEqual(0x00FF, pf.true_color.blue_max);
    try std.testing.expectEqual(16, pf.true_color.red_shift);
    try std.testing.expectEqual(8, pf.true_color.green_shift);
    try std.testing.expectEqual(0, pf.true_color.blue_shift);

    var out = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer out.deinit();

    try pf.write(&out.writer);

    try std.testing.expectEqualSlices(u8, &buf, out.written());
}

test "color map" {
    const buf = [_]u8{
        0x08, // bits per pixel
        0x06, // depth
        0x01, // big endian
        0x00, // true color

        // padding
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
    };

    std.debug.assert(buf.len == 16);

    var r = std.Io.Reader.fixed(&buf);

    const pf = try PixelFormat.read(&r);

    try std.testing.expectEqual(.color_map, std.meta.activeTag(pf));
    try std.testing.expectEqual(8, pf.color_map.bits_per_pixel);
    try std.testing.expectEqual(6, pf.color_map.depth);
    try std.testing.expectEqual(true, pf.color_map.big_endian);
    try std.testing.expectEqual(null, pf.color_map.color_map);

    var out = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer out.deinit();

    try pf.write(&out.writer);

    try std.testing.expectEqualSlices(u8, &buf, out.written());
}

test "stream convert" {
    const start_pf = PixelFormat.tc24_32le_rgb;
    const after_pf = PixelFormat.tc24_24le_bgr;

    const initial_bytes = [_]u8{
        0, 1, 2, 0, // 0
        1, 2, 3, 0, // 1
        2, 3, 4, 0, // 2
        3, 4, 5, 0, // 3
        4, 5, 6, 0, // 4
        5, 6, 7, 0, // 5
        6, 7, 8, 0, // 6
        7, 8, 9, 0, // 7
    };

    const expected_bytes = [_]u8{
        2, 1, 0, // 0
        3, 2, 1, // 1
        4, 3, 2, // 2
        5, 4, 3, // 3
        6, 5, 4, // 4
        7, 6, 5, // 5
        8, 7, 6, // 6
        9, 8, 7, // 7
    };

    var read_buf: [4]u8 = undefined;

    var initial_reader = std.Io.Reader.fixed(&initial_bytes);
    var limited_reader = initial_reader.limited(.unlimited, &read_buf);

    var after_buf: [24]u8 = undefined;
    var after_writer = std.Io.Writer.fixed(&after_buf);

    start_pf.streamConvert(&limited_reader.interface, &after_writer, &after_pf, 8) catch unreachable;

    try std.testing.expectEqualSlices(u8, &expected_bytes, &after_buf);
}
