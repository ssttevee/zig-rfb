const std = @import("std");
const root = @import("../../root.zig");

const ConstRc = @import("../../rc.zig").ConstRc;

const PixelFormat = root.PixelFormat;
const EncodingPayload = root.EncodingPayload;
const Rectangle = root.Rectangle;
const CustomEncodingHandlerFn = root.CustomEncodingHandlerFn;

const FramebufferUpdate = @This();

const StreamEncodingPayloadIterator = struct {
    arena: std.heap.ArenaAllocator,
    reader: *std.Io.Reader,
    pixel_format: *const PixelFormat,
    custom_encoding_handler: ?*const CustomEncodingHandlerFn,
    custom_encoding_handler_data: ?*anyopaque,

    interface: EncodingPayload.Iterator = .{
        .vtable = &.{
            .next = nextFn,
            .destroy = destroyFn,
        },
    },

    fn nextFn(interface: *EncodingPayload.Iterator) EncodingPayload.ReadError!EncodingPayload {
        const self: *StreamEncodingPayloadIterator = @fieldParentPtr("interface", interface);
        _ = self.arena.reset(.retain_capacity);

        return try EncodingPayload.read(
            self.arena.allocator(),
            self.reader,
            self.pixel_format,
            self.custom_encoding_handler,
            self.custom_encoding_handler_data,
        );
    }

    fn destroyFn(interface: *EncodingPayload.Iterator, allocator: std.mem.Allocator) void {
        const self: *StreamEncodingPayloadIterator = @fieldParentPtr("interface", interface);
        self.arena.deinit();
        allocator.destroy(self);
        self.* = undefined;
    }
};

payload_iterator: *EncodingPayload.Iterator,

pub fn read(
    allocator: std.mem.Allocator,
    r: *std.Io.Reader,
    pixel_format: *const PixelFormat,
    custom_encoding_handler: ?*const CustomEncodingHandlerFn,
    custom_encoding_handler_data: ?*anyopaque,
) !FramebufferUpdate {
    _ = try r.takeByte(); // discard padding

    const number_of_rectangles = try r.takeInt(u16, .big);
    const it = try allocator.create(StreamEncodingPayloadIterator);
    it.* = .{
        .arena = .init(allocator),
        .reader = r,
        .pixel_format = pixel_format,
        .custom_encoding_handler = custom_encoding_handler,
        .custom_encoding_handler_data = custom_encoding_handler_data,
    };
    it.interface.len = number_of_rectangles;
    return .{
        .payload_iterator = &it.interface,
    };
}

pub fn write(self: *const FramebufferUpdate, w: *std.Io.Writer, pixel_format: *const PixelFormat) !void {
    try w.writeAll(&.{
        0, // padding
    });
    try w.writeInt(u16, self.payload_iterator.len, .big);
    while (try self.payload_iterator.next()) |payload| {
        try payload.write(w, pixel_format);
    }
}

/// Release all owned memory.
///
/// Always call `drainRemaining()` before `deinit()` or else the stream may become
/// irrecoverably corrupted.
pub fn deinit(self: *FramebufferUpdate, allocator: std.mem.Allocator) void {
    std.debug.assert(self.payload_iterator.len <= self.payload_iterator.pos);
    self.payload_iterator.deinit(allocator);
    self.* = undefined;
}

/// Read the next payload.
///
/// Returned memory ownership is not transferred to the caller, do not
/// call `deinit` on the returned payload.
pub fn next(self: *FramebufferUpdate) !?EncodingPayload {
    return try self.payload_iterator.next();
}

/// Discard the remaining payloads.
///
/// Always call `drainRemaining()` before `deinit()` or else the stream may become
/// irrecoverably corrupted.
pub fn drainRemaining(self: *FramebufferUpdate) !void {
    while (try self.payload_iterator.next()) |_| {}
}
