const std = @import("std");
const root = @import("../root.zig");

const PixelFormat = root.PixelFormat;
const SecurityType = root.SecurityType;
const ClientSecurity = root.ClientSecurity;
const ClientOptions = root.ClientOptions;
const ClientMessage = root.ClientMessage;
const Point = root.Point;
const EncodingPayload = root.EncodingPayload;
const ServerMessage = root.ServerMessage;
const Rectangle = root.Rectangle;
const ColorMap = root.ColorMap;

const Connection = @This();

allocator: std.mem.Allocator,
input: *std.Io.Reader,
output: *std.Io.Writer,
framebuffer_size: Point,
pixel_format: PixelFormat,
name: []const u8,

custom_message_handler: ?*const ServerMessage.Custom.HandlerFn = null,
custom_message_handler_data: ?*anyopaque = null,

custom_encoding_handler: ?*const EncodingPayload.Custom.HandlerFn = null,
custom_encoding_handler_data: ?*anyopaque = null,

pub const SecurityCallback = fn (
    allocator: std.mem.Allocator,
    security_types: []SecurityType,
    data: ?*anyopaque,
) anyerror!ClientSecurity;

pub fn init(
    allocator: std.mem.Allocator,
    input: *std.Io.Reader,
    output: *std.Io.Writer,
    options: ClientOptions,
    security_callback: *const SecurityCallback,
    security_callback_data: ?*anyopaque,
    reason_out: ?*?[]const u8,
) !Connection {
    const step, const security_types = try root.clientHandshake(allocator, input, output, reason_out);

    const security = blk: {
        defer allocator.free(security_types);
        break :blk try security_callback(allocator, security_types, security_callback_data);
    };

    const server_info = try step.next(allocator, input, output, security, options, reason_out);
    return .{
        .allocator = allocator,
        .input = input,
        .output = output,
        .pixel_format = server_info.pixel_format,
        .framebuffer_size = server_info.framebuffer_size,
        .name = server_info.name,
    };
}

pub fn deinit(self: *Connection) void {
    self.pixel_format.deinit(self.allocator);
    self.allocator.free(self.name);
    self.* = undefined;
}

pub fn readMessage(self: *Connection) !ServerMessage {
    const message = try ServerMessage.read(
        self.allocator,
        self.input,
        &self.pixel_format,
        self.custom_message_handler,
        self.custom_message_handler_data,
        self.custom_encoding_handler,
        self.custom_encoding_handler_data,
    );
    switch (message) {
        else => {},
        .native => |native| switch (native) {
            else => {},
            .set_color_map_entries => |scme| {
                try self.pixel_format.setColorMap(self.allocator, scme.color_map);
            },
        },
    }

    return message;
}

pub fn writeMessage(self: *Connection, message: ClientMessage) !void {
    try message.write(self.output);
    try self.output.flush();

    switch (message) {
        else => {},
        .native => |native| switch (native) {
            else => {},
            .set_pixel_format => |spf| {
                self.pixel_format.deinit(self.allocator);
                self.pixel_format = spf.pixel_format;
            },
            .set_color_map_entries => |scme| {
                try self.pixel_format.setColorMap(self.allocator, scme.color_map);
            },
        },
    }
}

pub fn writeNativeMessage(self: *Connection, message: ClientMessage.Native) !void {
    try self.writeMessage(.{ .native = message });
}

pub fn writeCustomMessage(self: *Connection, message: *ClientMessage.Custom) !void {
    try self.writeMessage(.{ .custom = message });
}

pub fn writeSetPixelFormatMessage(self: *Connection, message: ClientMessage.SetPixelFormat) !void {
    try self.writeNativeMessage(.{ .set_pixel_format = message });
}

pub fn writeSetColorMapEntriesMessage(self: *Connection, message: ClientMessage.SetColorMapEntries) !void {
    try self.writeNativeMessage(.{ .set_color_map_entries = message });
}

pub fn writeSetEncodingsMessage(self: *Connection, message: ClientMessage.SetEncodings) !void {
    try self.writeNativeMessage(.{ .set_encodings = message });
}

pub fn writeFramebufferUpdateRequestMessage(self: *Connection, message: ClientMessage.FramebufferUpdateRequest) !void {
    try self.writeNativeMessage(.{ .framebuffer_update_request = message });
}

pub fn writeKeyEventMessage(self: *Connection, message: ClientMessage.KeyEvent) !void {
    try self.writeNativeMessage(.{ .key_event = message });
}

pub fn writePointerEventMessage(self: *Connection, message: ClientMessage.PointerEvent) !void {
    try self.writeNativeMessage(.{ .pointer_event = message });
}

pub fn writeCutTextMessage(self: *Connection, message: ClientMessage.CutText) !void {
    try self.writeNativeMessage(.{ .cut_text = message });
}
