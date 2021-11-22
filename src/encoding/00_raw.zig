const std = @import("std");
const root = @import("../root.zig");

const Rectangle = root.Rectangle;
const PixelFormat = root.PixelFormat;
const Image = root.Image;
const NativeEncodingType = root.NativeEncodingType;

pub const Payload = @This();

/// Raw image data.
///
/// Do not call `take()` on this image if this payload originates from
/// `ServerMessage.read()` because it will be released together with the
/// message and become invalid. Instead, use `clone()` to get a copy that
/// can be used independently.
image: Image,

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader, pixel_format: *const PixelFormat, rect: Rectangle) !Payload {
    const bpp = pixel_format.bytesPerPixel();
    return .{
        .image = .{
            .rect = rect,
            .stride = rect.w * bpp,
            .data = try r.readAlloc(allocator, rect.w * rect.h * bpp),
            .pixel_format = pixel_format.clone(),
        },
    };
}

pub fn write(self: *const Payload, w: *std.Io.Writer, pixel_format: *const PixelFormat) !void {
    try w.writeInt(u16, @truncate(self.image.rect.x), .big);
    try w.writeInt(u16, @truncate(self.image.rect.y), .big);
    try w.writeInt(u16, @truncate(self.image.rect.w), .big);
    try w.writeInt(u16, @truncate(self.image.rect.h), .big);
    try w.writeInt(u32, @intFromEnum(NativeEncodingType.raw), .big);
    try self.image.writeConvert(w, pixel_format);
}

pub fn deinit(self: *Payload, allocator: std.mem.Allocator) void {
    self.image.deinit(allocator);
    self.* = undefined;
}
