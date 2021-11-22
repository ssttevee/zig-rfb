const std = @import("std");
const root = @import("root.zig");

const ConstRc = @import("rc.zig").ConstRc;

const Color = root.Color;
const PixelFormat = root.PixelFormat;
const Rectangle = root.Rectangle;
const Point = root.Point;

const Image = @This();

rect: Rectangle,
stride: usize,
data: []const u8,
pixel_format: PixelFormat,

pub fn init(allocator: std.mem.Allocator, size: Point, pixel_format: *const PixelFormat) !Image {
    const stride = size.x * pixel_format.bytesPerPixel();
    const data = try allocator.alloc(u8, stride * size.y);
    return Image{
        .rect = Rectangle{ .x = 0, .y = 0, .w = size.x, .h = size.y },
        .stride = stride,
        .data = data,
        .pixel_format = pixel_format.clone(),
    };
}

pub fn deinit(self: *Image, allocator: std.mem.Allocator) void {
    allocator.free(self.data);
    self.pixel_format.deinit(allocator);
    self.* = undefined;
}

/// Assume ownership of the image data.
///
/// After `take` is called, the image is invalid and any further method calls
/// constitute undefined behaviour except for `deinit`.
pub fn take(self: *Image) Image {
    const data, self.data = .{ self.data, &.{} };

    return .{
        .rect = self.rect,
        .stride = self.stride,
        .data = data,
        .pixel_format = self.pixel_format.clone(),
    };
}

pub fn clone(self: *const Image, allocator: std.mem.Allocator) !Image {
    return .{
        .rect = self.rect,
        .stride = self.stride,
        .data = try allocator.dupe(u8, self.data),
        .pixel_format = self.pixel_format.clone(),
    };
}

pub inline fn width(self: *const Image) usize {
    return self.rect.w;
}

pub inline fn height(self: *const Image) usize {
    return self.rect.h;
}

pub fn colorAt(self: *const Image, x: usize, y: usize) !Color {
    const our_format = self.pixel_format;
    const offset = (y + self.rect.y) * self.stride + (x + self.rect.x) * our_format.bytesPerPixel();
    return our_format.unpack(self.data[offset..]);
}

pub fn writeConvert(self: *const Image, w: *std.Io.Writer, new_format: *const PixelFormat) !void {
    const our_format = self.pixel_format;
    const bpp = our_format.bytesPerPixel();
    if (our_format.eql(new_format)) {
        for (0..self.rect.h) |y| {
            const y_offset = y * self.stride;
            try w.writeAll(self.data[y_offset .. y_offset + self.rect.w * bpp]);
        }

        return;
    }

    var buf: [8]u8 = undefined;

    for (0..self.rect.h) |y| {
        const y_offset = y * self.stride;

        for (0..self.rect.w) |x| {
            try w.writeAll(
                our_format.convert(
                    self.data[y_offset + x * bpp ..],
                    new_format,
                    &buf,
                ) catch unreachable,
            );
        }
    }
}

pub fn convertAlloc(self: *const Image, allocator: std.mem.Allocator, new_format: *const PixelFormat) !Image {
    const buf = try allocator.alloc(u8, new_format.minBytes(self.rect.w, self.rect.h));
    errdefer allocator.free(buf);

    self.convertBuf(new_format, buf) catch unreachable;

    return Image{
        .rect = self.rect,
        .stride = self.rect.w * new_format.bytesPerPixel(),
        .data = buf,
        .pixel_format = new_format.clone(),
    };
}

pub fn convertBuf(self: *const Image, new_format: *const PixelFormat, buf: []u8) !Image {
    // calculate size required for other pixel format
    if (new_format.minBytes(self.rect.w, self.rect.h) > buf.len) {
        return error.NotEnoughSpace;
    }

    const our_format = self.pixel_format;
    const our_bpp = our_format.bytesPerPixel();

    const new_bpp = new_format.bytesPerPixel();
    const new_stride = self.rect.w * new_bpp;
    for (0..self.rect.h) |y| {
        const our_y_offset = y * self.stride;
        const new_y_offset = y * new_stride;

        for (0..self.rect.w) |x| {
            _ = our_format.convert(
                self.data[our_y_offset + x * our_bpp ..],
                new_format,
                buf[new_y_offset + x * new_bpp ..],
            ) catch unreachable;
        }
    }

    return Image{
        .rect = self.rect,
        .stride = self.rect.w * new_bpp,
        .data = buf,
        .pixel_format = new_format.clone(),
    };
}

// pub fn subimage(self: *const Image, rect: Rectangle) Image {}

test "convertBuf le" {
    var wrgbBuf = [_]u8{
        0xff, 0xff, 0xff, 0x00, // white
        0x00, 0x00, 0xff, 0x00, // red
        0x00, 0xff, 0x00, 0x00, // green
        0xff, 0x00, 0x00, 0x00, // blue
    };
    const wrgb = Image{
        .rect = .{
            .x = 0,
            .y = 0,
            .w = 2,
            .h = 2,
        },
        .stride = 8,
        .data = &wrgbBuf,
        .pixel_format = .tc24_32le_rgb,
    };

    {
        var buf = [_]u8{0} ** 16;
        const converted = try wrgb.convertBuf(&.tc24_32le_bgr, &buf);

        try std.testing.expectEqual(wrgb.rect, converted.rect);
        try std.testing.expectEqual(8, converted.stride);
        try std.testing.expectEqual(PixelFormat.tc24_32le_bgr, converted.pixel_format);
        try std.testing.expectEqualSlices(u8, &[_]u8{
            0xff, 0xff, 0xff, 0x00, // white
            0xff, 0x00, 0x00, 0x00, // red
            0x00, 0xff, 0x00, 0x00, // green
            0x00, 0x00, 0xff, 0x00, // blue
        }, converted.data);
    }

    {
        var buf = [_]u8{0} ** 16;
        const converted = try wrgb.convertBuf(&.tc24_32be_rgb, &buf);

        try std.testing.expectEqual(wrgb.rect, converted.rect);
        try std.testing.expectEqual(8, converted.stride);
        try std.testing.expectEqual(PixelFormat.tc24_32be_rgb, converted.pixel_format);
        try std.testing.expectEqualSlices(u8, &[_]u8{
            0x00, 0xff, 0xff, 0xff, // white
            0x00, 0xff, 0x00, 0x00, // red
            0x00, 0x00, 0xff, 0x00, // green
            0x00, 0x00, 0x00, 0xff, // blue
        }, converted.data);
    }

    {
        var buf = [_]u8{0} ** 16;
        const converted = try wrgb.convertBuf(&.tc24_32be_bgr, &buf);

        try std.testing.expectEqual(wrgb.rect, converted.rect);
        try std.testing.expectEqual(8, converted.stride);
        try std.testing.expectEqual(PixelFormat.tc24_32be_bgr, converted.pixel_format);
        try std.testing.expectEqualSlices(u8, &[_]u8{
            0x00, 0xff, 0xff, 0xff, // white
            0x00, 0x00, 0x00, 0xff, // red
            0x00, 0x00, 0xff, 0x00, // green
            0x00, 0xff, 0x00, 0x00, // blue
        }, converted.data);
    }
}

test "convertBuf be" {
    var wrgbBuf = [_]u8{
        0x00, 0xff, 0xff, 0xff, // white
        0x00, 0xff, 0x00, 0x00, // red
        0x00, 0x00, 0xff, 0x00, // green
        0x00, 0x00, 0x00, 0xff, // blue
    };
    const wrgb = Image{
        .rect = .{
            .x = 0,
            .y = 0,
            .w = 2,
            .h = 2,
        },
        .stride = 8,
        .data = &wrgbBuf,
        .pixel_format = .tc24_32be_rgb,
    };

    {
        var buf = [_]u8{0} ** 16;
        const converted = try wrgb.convertBuf(&.tc24_32le_rgb, &buf);

        try std.testing.expectEqual(wrgb.rect, converted.rect);
        try std.testing.expectEqual(8, converted.stride);
        try std.testing.expectEqual(PixelFormat.tc24_32le_rgb, converted.pixel_format);
        try std.testing.expectEqualSlices(u8, &[_]u8{
            0xff, 0xff, 0xff, 0x00, // white
            0x00, 0x00, 0xff, 0x00, // red
            0x00, 0xff, 0x00, 0x00, // green
            0xff, 0x00, 0x00, 0x00, // blue
        }, converted.data);
    }

    {
        var buf = [_]u8{0} ** 16;
        const converted = try wrgb.convertBuf(&.tc24_32le_bgr, &buf);

        try std.testing.expectEqual(wrgb.rect, converted.rect);
        try std.testing.expectEqual(8, converted.stride);
        try std.testing.expectEqual(PixelFormat.tc24_32le_bgr, converted.pixel_format);
        try std.testing.expectEqualSlices(u8, &[_]u8{
            0xff, 0xff, 0xff, 0x00, // white
            0xff, 0x00, 0x00, 0x00, // red
            0x00, 0xff, 0x00, 0x00, // green
            0x00, 0x00, 0xff, 0x00, // blue
        }, converted.data);
    }

    {
        var buf = [_]u8{0} ** 16;
        const converted = try wrgb.convertBuf(&.tc24_32be_bgr, &buf);

        try std.testing.expectEqual(wrgb.rect, converted.rect);
        try std.testing.expectEqual(8, converted.stride);
        try std.testing.expectEqual(PixelFormat.tc24_32be_bgr, converted.pixel_format);
        try std.testing.expectEqualSlices(u8, &[_]u8{
            0x00, 0xff, 0xff, 0xff, // white
            0x00, 0x00, 0x00, 0xff, // red
            0x00, 0x00, 0xff, 0x00, // green
            0x00, 0xff, 0x00, 0x00, // blue
        }, converted.data);
    }
}
