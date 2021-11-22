const std = @import("std");

const client = @This();

pub const TypeInt = u8;

pub const SetPixelFormat = @import("client/00_set_pixel_format.zig");
pub const SetColorMapEntries = @import("common/set_color_map_entries.zig");
pub const SetEncodings = @import("client/02_set_encodings.zig");
pub const FramebufferUpdateRequest = @import("client/03_framebuffer_update_request.zig");
pub const KeyEvent = @import("client/04_key_event.zig");
pub const PointerEvent = @import("client/05_pointer_event.zig");
pub const CutText = @import("common/cut_text.zig");

pub const Native = union(enum(TypeInt)) {
    set_pixel_format: SetPixelFormat = 0,
    set_color_map_entries: SetColorMapEntries = 1,
    set_encodings: SetEncodings = 2,
    framebuffer_update_request: FramebufferUpdateRequest = 3,
    key_event: KeyEvent = 4,
    pointer_event: PointerEvent = 5,
    cut_text: CutText = 6,

    // --- Optional Message Types ---

    // file_transfer = 7,
    // set_scale = 8,
    // set_server_input = 9,
    // set_sw = 10,
    // text_chat = 11,
    // key_frame_request = 12,
    // keep_alive = 13,

    // set_scale_factor = 15,
    // request_session = 20,
    // set_session = 21,

    // notify_plugin_streaming = 80,
    // vmware = 127,
    // car_connectivity = 128,
    // enable_continuous_updates = 150,
    // client_fence = 248,
    // olive_call_control = 249,
    // xvp = 250,
    // set_desktop_size = 251,
    // tight = 252,
    // gii = 253,
    // vmware2 = 254,
    // qemu = 255,

    pub fn write(self: *const Native, w: *std.Io.Writer) !void {
        switch (self.*) {
            inline else => |*msg| try msg.write(w),
        }
    }

    pub fn deinit(self: *Native, allocator: std.mem.Allocator) void {
        switch (self.*) {
            inline else => |*msg| msg.deinit(allocator),
        }
        self.* = undefined;
    }
};

pub const Custom = struct {
    type: TypeInt,
    vtable: *const VTable,

    pub const ReadError = std.Io.Reader.Error;
    pub const WriteError = std.Io.Writer.Error;

    pub const HandlerFn = fn (
        allocator: std.mem.Allocator,
        r: *std.Io.Reader,
        message_type: TypeInt,
        data: ?*anyopaque,
    ) ReadError!?*Message.Custom;

    pub const VTable = struct {
        write: *const fn (*const Custom, w: *std.Io.Writer) WriteError!void,
        destroy: *const fn (*Custom, allocator: std.mem.Allocator) void,
    };

    pub inline fn write(self: *const Custom, w: *std.Io.Writer) !void {
        try self.vtable.write(self, w);
    }

    pub inline fn deinit(self: *Custom, allocator: std.mem.Allocator) void {
        self.vtable.destroy(self, allocator);
    }
};

pub const Message = union(enum) {
    native: Message.Native,
    custom: *Message.Custom,

    pub const Native = client.Native;
    pub const Custom = client.Custom;

    pub const Type = client.Type;
    pub const CustomHandlerFn = Message.Custom.HandlerFn;

    pub const SetPixelFormat = client.SetPixelFormat;
    pub const SetColorMapEntries = client.SetColorMapEntries;
    pub const SetEncodings = client.SetEncodings;
    pub const FramebufferUpdateRequest = client.FramebufferUpdateRequest;
    pub const KeyEvent = client.KeyEvent;
    pub const PointerEvent = client.PointerEvent;
    pub const CutText = client.CutText;

    pub fn @"type"(self: *const Message) Message.Type {
        return switch (self.*) {
            .native => |msg| .{ .native = msg },
            .custom => |custom| .fromInt(custom.type),
        };
    }

    pub fn initNative(native: Message.Native) Message {
        return .{ .native = native };
    }

    pub fn initCustom(custom: *Message.Custom) Message {
        return .{ .custom = custom };
    }

    pub fn initSetPixelFormat(set_pixel_format: Message.SetPixelFormat) Message {
        return .initNative(.{ .set_pixel_format = set_pixel_format });
    }

    pub fn initSetColorMapEntries(set_color_map_entries: Message.SetColorMapEntries) Message {
        return .initNative(.{ .set_color_map_entries = set_color_map_entries });
    }

    pub fn initSetEncodings(set_encodings: Message.SetEncodings) Message {
        return .initNative(.{ .set_encodings = set_encodings });
    }

    pub fn initFramebufferUpdateRequest(framebuffer_update_request: Message.FramebufferUpdateRequest) Message {
        return .initNative(.{ .framebuffer_update_request = framebuffer_update_request });
    }

    pub fn initKeyEvent(key_event: Message.KeyEvent) Message {
        return .initNative(.{ .key_event = key_event });
    }

    pub fn initPointerEvent(pointer_event: Message.PointerEvent) Message {
        return .initNative(.{ .pointer_event = pointer_event });
    }

    pub fn initCutText(cut_text: Message.CutText) Message {
        return .initNative(.{ .cut_text = cut_text });
    }

    pub fn read(
        allocator: std.mem.Allocator,
        r: *std.Io.Reader,
        custom_message_handler: ?*const Message.CustomHandlerFn,
        custom_message_handler_data: ?*anyopaque,
    ) !Message {
        const message_type = try r.takeInt(TypeInt, .big);
        if (custom_message_handler) |handler| {
            if (try handler(allocator, r, message_type, custom_message_handler_data)) |payload| {
                return .{ .custom = payload };
            }
        }

        if (std.enums.fromInt(NativeType, message_type)) |native_type| {
            return .{
                .native = switch (native_type) {
                    inline else => |tag| @unionInit(
                        Message.Native,
                        @tagName(tag),
                        try .read(allocator, r),
                    ),
                },
            };
        }

        return error.UnsupportedMessageType;
    }

    pub fn write(self: *const Message, w: *std.Io.Writer) !void {
        try w.writeInt(TypeInt, self.type().toInt(), .big);
        switch (self.*) {
            inline else => |msg| try msg.write(w),
        }
    }

    pub fn deinit(self: *Message, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .native => |*native| native.deinit(allocator),
            .custom => |custom| custom.deinit(allocator),
        }
        self.* = undefined;
    }
};

pub const NativeType = std.meta.Tag(Native);

pub const Type = union(enum) {
    native: NativeType,
    custom: TypeInt,

    pub const Int = TypeInt;

    pub const set_pixel_format = fromEnum(.set_pixel_format);
    pub const set_color_map_entries = fromEnum(.set_color_map_entries);
    pub const set_encodings = fromEnum(.set_encodings);
    pub const framebuffer_update_request = fromEnum(.framebuffer_update_request);
    pub const key_event = fromEnum(.key_event);
    pub const pointer_event = fromEnum(.pointer_event);
    pub const cut_text = fromEnum(.cut_text);

    pub fn fromEnum(value: NativeType) Type {
        return .{ .native = value };
    }

    pub fn fromInt(value: TypeInt) Type {
        if (std.enums.fromInt(NativeType, value)) |native| {
            return .{ .native = native };
        }

        return .{ .custom = value };
    }

    pub fn toInt(self: Type) TypeInt {
        return switch (self) {
            .native => |native| @intFromEnum(native),
            .custom => |custom| custom,
        };
    }

    pub fn eql(self: Type, other: Type) bool {
        return self.toInt() == other.toInt();
    }
};
