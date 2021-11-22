const std = @import("std");
const root = @import("../root.zig");

const PixelFormat = root.PixelFormat;
const Rectangle = root.Rectangle;
const CustomEncodingHandlerFn = root.CustomEncodingHandlerFn;

pub const FramebufferUpdate = @import("server/00_framebuffer_update.zig");
pub const SetColorMapEntries = @import("common/set_color_map_entries.zig");
pub const Bell = @import("server/02_bell.zig");
pub const CutText = @import("common/cut_text.zig");

const server = @This();

pub const TypeInt = u8;

pub const Native = union(enum(TypeInt)) {
    framebuffer_update: FramebufferUpdate = 0,
    set_color_map_entries: SetColorMapEntries = 1,
    bell: Bell = 2,
    cut_text: CutText = 3,

    // --- Optional Message Types ---

    // resize_frame_buffer = 4,
    // key_frame_update = 5

    // file_transfer = 7
    // text_chat = 11
    // keep_alive = 13
    // resize_frame_buffer2 = 15

    // vmware = 127
    // car_connectivity = 128
    // end_of_continuous_updates = 150
    // server_state = 173
    // server_fence = 248
    // olive_call_control = 249
    // xvp = 250
    // tight = 252
    // gii = 253
    // vmware2 = 254
    // qemu = 255

    pub fn write(self: *const Native, w: *std.Io.Writer, pixel_format: *const PixelFormat) !void {
        switch (self.*) {
            inline else => |msg| try msg.write(w),
            .framebuffer_update => |fu| try fu.write(w, pixel_format),
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
        pixel_format: *const PixelFormat,
        message_type: TypeInt,
        data: ?*anyopaque,
    ) ReadError!?*Message.Custom;

    pub const VTable = struct {
        write: *const fn (*const Custom, w: *std.Io.Writer, pixel_format: *const PixelFormat) WriteError!void,
        destroy: *const fn (*Custom, allocator: std.mem.Allocator) void,
    };

    pub inline fn write(self: *const Custom, w: *std.Io.Writer, pixel_format: *const PixelFormat) !void {
        try self.vtable.write(self, w, pixel_format);
    }

    pub inline fn deinit(self: *Custom, allocator: std.mem.Allocator) void {
        self.vtable.destroy(self, allocator);
    }
};

pub const Message = union(enum) {
    native: Message.Native,
    custom: *Message.Custom,

    pub const Native = server.Native;
    pub const Custom = server.Custom;

    pub const Type = server.Type;
    pub const CustomHandlerFn = Message.Custom.HandlerFn;

    pub const FramebufferUpdate = server.FramebufferUpdate;
    pub const SetColorMapEntries = server.SetColorMapEntries;
    pub const Bell = server.Bell;
    pub const CutText = server.CutText;

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

    pub fn initFramebufferUpdate(framebuffer_update: Message.FramebufferUpdate) Message {
        return .initNative(.{ .framebuffer_update = framebuffer_update });
    }

    pub fn initSetColorMapEntries(set_color_map_entries: Message.SetColorMapEntries) Message {
        return .initNative(.{ .set_color_map_entries = set_color_map_entries });
    }

    pub fn initBell(bell: Message.Bell) Message {
        return .initNative(.{ .bell = bell });
    }

    pub fn initCutText(cut_text: Message.CutText) Message {
        return .initNative(.{ .cut_text = cut_text });
    }

    pub fn read(
        allocator: std.mem.Allocator,
        r: *std.Io.Reader,
        pixel_format: *const PixelFormat,
        custom_message_handler: ?*const Message.CustomHandlerFn,
        custom_message_handler_data: ?*anyopaque,
        custom_encoding_handler: ?*const CustomEncodingHandlerFn,
        custom_encoding_handler_data: ?*anyopaque,
    ) !Message {
        const message_type = try r.takeInt(TypeInt, .big);
        if (custom_message_handler) |handler| {
            if (try handler(allocator, r, pixel_format, message_type, custom_message_handler_data)) |payload| {
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
                    .framebuffer_update => .{
                        .framebuffer_update = try .read(
                            allocator,
                            r,
                            pixel_format,
                            custom_encoding_handler,
                            custom_encoding_handler_data,
                        ),
                    },
                },
            };
        }

        return error.UnsupportedMessageType;
    }

    pub fn write(self: *const Message, w: *std.Io.Writer, pixel_format: *const PixelFormat) !void {
        try w.writeInt(TypeInt, self.type().toInt(), .big);
        switch (self.*) {
            inline else => |msg| try msg.write(w, pixel_format),
        }
    }

    /// Releases all owned memory
    ///
    /// For `FramebufferUpdate`, always call `drainRemaining()` before
    /// `deinit()` or else the stream may become irrecoverably corrupted.
    ///
    /// Note that `deinit()` does not always need to be called, especially on
    /// the server side. In particular, when payload iterator is stack
    /// allocated, the convenience `Slice` iterator assumes a heap allocated
    /// slice. Please be mindful of whether it is necessary to call `deinit()`.
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

    pub const framebuffer_update = fromEnum(.framebuffer_update);
    pub const set_color_map_entries = fromEnum(.set_color_map_entries);
    pub const bell = fromEnum(.bell);
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
