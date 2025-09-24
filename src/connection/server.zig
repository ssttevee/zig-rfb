const std = @import("std");
const root = @import("../root.zig");

const PixelFormat = root.PixelFormat;
const ServerSecurity = root.ServerSecurity;
const ServerSecurityPayload = root.ServerSecurityPayload;
const ServerInfo = root.ServerInfo;
const ClientMessage = root.ClientMessage;
const ServerMessage = root.ServerMessage;
const ColorMap = root.ColorMap;
const EncodingType = root.EncodingType;
const EncodingPayload = root.EncodingPayload;
const EncodingPayloadIterator = root.EncodingPayloadIterator;
const Image = root.Image;

const Connection = @This();

allocator: std.mem.Allocator,
input: *std.Io.Reader,
output: *std.Io.Writer,
pixel_format: PixelFormat,
shared: bool = false,
supported_encodings: ?std.AutoArrayHashMapUnmanaged(EncodingType.Int, void) = null,

custom_message_handler: ?*const ClientMessage.Custom.HandlerFn = null,
custom_message_handler_data: ?*anyopaque = null,

pub const SecurityPayloadCallback = fn (
    allocator: std.mem.Allocator,
    security_payload: ServerSecurityPayload,
    reason_out: *?[]const u8,
    data: ?*anyopaque,
) anyerror!bool;

pub fn init(
    allocator: std.mem.Allocator,
    input: *std.Io.Reader,
    output: *std.Io.Writer,
    server_info: ServerInfo,
    security_candidates: []const ServerSecurity,
    security_payload_callback: ?*const SecurityPayloadCallback,
    security_payload_callback_data: ?*anyopaque,
) !Connection {
    const step, const security_payload = try root.serverHandshake(allocator, input, output, security_candidates);

    if (security_payload_callback) |callback| {
        var reason: ?[]const u8 = null;
        if (!try callback(allocator, security_payload, &reason, security_payload_callback_data)) {
            step.reject(output, reason orelse "rejected") catch {};
            return error.Rejected;
        }
    }

    const options = try step.next(input, output, server_info);

    return .{
        .allocator = allocator,
        .input = input,
        .output = output,
        .pixel_format = server_info.pixel_format,
        .shared = options.shared,
    };
}

pub fn deinit(self: *Connection) void {
    if (self.supported_encodings) |*encodings| {
        encodings.deinit(self.allocator);
    }
    self.pixel_format.deinit(self.allocator);
    self.* = undefined;
}

pub fn readMessage(self: *Connection) !ClientMessage {
    var message = try ClientMessage.read(
        self.allocator,
        self.input,
        self.custom_message_handler,
        self.custom_message_handler_data,
    );
    switch (message) {
        else => {},
        .native => |*native| switch (native.*) {
            else => {},
            .set_pixel_format => |spf| {
                self.pixel_format.deinit(self.allocator);
                self.pixel_format = spf.pixel_format;
            },
            .set_color_map_entries => |scme| {
                try self.pixel_format.setColorMap(self.allocator, scme.color_map);
            },
            .set_encodings => |*se| {
                if (self.supported_encodings) |*encodings| {
                    encodings.deinit(self.allocator);
                }

                const encoding_ints = try self.allocator.alloc(EncodingType.Int, se.encodings.len);
                errdefer self.allocator.free(encoding_ints);
                for (se.encodings, 0..) |encoding, i| {
                    encoding_ints[i] = encoding.toInt();
                }

                self.supported_encodings = try .init(self.allocator, encoding_ints, &.{});
            },
        },
    }

    return message;
}

pub fn writeMessage(self: *Connection, message: ServerMessage) !void {
    try message.write(self.output, &self.pixel_format);
    try self.output.flush();

    switch (message) {
        else => {},
        .native => |native| switch (native) {
            else => {},
            .set_color_map_entries => |scme| {
                try self.pixel_format.setColorMap(self.allocator, scme.color_map);
            },
        },
    }
}

pub fn writeNativeMessage(self: *Connection, message: ServerMessage.Native) !void {
    try self.writeMessage(.{ .native = message });
}

pub fn writeCustomMessage(self: *Connection, message: *ServerMessage.Custom) !void {
    try self.writeMessage(.{ .custom = message });
}

pub fn writeFramebufferUpdateMessage(self: *Connection, message: ServerMessage.FramebufferUpdate) !void {
    try self.writeNativeMessage(.{ .framebuffer_update = message });
}

pub fn writeFramebufferPayloads(self: *Connection, payload_iterator: *EncodingPayloadIterator) !void {
    try self.writeFramebufferUpdateMessage(.{ .payload_iterator = payload_iterator });
}

pub fn writeFramebufferPayloadSlice(self: *Connection, payloads: []const EncodingPayload) !void {
    var it = EncodingPayloadIterator.Slice.init(payloads);
    try self.writeFramebufferPayloads(&it.interface);
}

pub fn writeSetColorMapEntriesMessage(self: *Connection, message: ServerMessage.SetColorMapEntries) !void {
    try self.writeNativeMessage(.{ .set_color_map_entries = message });
}

pub fn writeBellMessage(self: *Connection, message: ServerMessage.Bell) !void {
    try self.writeNativeMessage(.{ .bell = message });
}

pub fn writeCutTextMessage(self: *Connection, message: ServerMessage.CutText) !void {
    try self.writeNativeMessage(.{ .cut_text = message });
}

pub fn writeRawFrame(self: *Connection, image: *const Image) !void {
    try self.writeFramebufferPayloadSlice(&.{.initRaw(.{ .image = image.* })});
}

pub fn isSupportedEncodingType(self: *const Connection, encoding_type: EncodingType) bool {
    if (self.supported_encodings) |supported_encodings| {
        return supported_encodings.contains(encoding_type);
    }

    return encoding_type.toInt() == EncodingType.raw.toInt();
}
