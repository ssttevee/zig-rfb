const std = @import("std");
const root = @import("root.zig");

const encoding = @This();

const ConstRc = @import("rc.zig").ConstRc;

const Rectangle = root.Rectangle;
const PixelFormat = root.PixelFormat;

pub const TypeInt = i32;

pub const RawPayload = @import("encoding/00_raw.zig");

pub const NativePayload = union(enum(TypeInt)) {
    raw: RawPayload = 0,
    // copy_rect = 1,
    // rre = 2,
    // corre = 4,
    // hextile = 5,
    // zlib = 6,
    // tight = 7,
    // zlibhex = 8,
    // zrle = 16,

    // --- Pseudo Encoding Types ---

    // jpeg_quality_level_10 = -23
    // jpeg_quality_level_9  = -24
    // jpeg_quality_level_8  = -25
    // jpeg_quality_level_7  = -26
    // jpeg_quality_level_6  = -27
    // jpeg_quality_level_5  = -28
    // jpeg_quality_level_4  = -29
    // jpeg_quality_level_3  = -30
    // jpeg_quality_level_2  = -31
    // jpeg_quality_level_1  = -32

    // desktop_size = -223
    // last_rect    = -224
    // cursor      = -239
    // x_cursor     = -240

    // compression_level_10 = -247
    // compression_level_9  = -248
    // compression_level_8  = -249
    // compression_level_7  = -250
    // compression_level_6  = -251
    // compression_level_5  = -252
    // compression_level_4  = -253
    // compression_level_3  = -254
    // compression_level_2  = -255
    // compression_level_1  = -256

    // qemu_pointer_motion_change = -257
    // qemu_extended_key_event    = -258
    // qemu_audio               = -259

    // gii                 = -305
    // desktop_name         = -307
    // extended_desktop_size = -308
    // xvp                 = -309

    // fence             = -312
    // continuous_updates = -313

    // jpeg_fine_grained_quality_level_100 = -412
    // jpeg_fine_grained_quality_level_99  = -413
    // jpeg_fine_grained_quality_level_98  = -414
    // jpeg_fine_grained_quality_level_97  = -415
    // jpeg_fine_grained_quality_level_96  = -416
    // jpeg_fine_grained_quality_level_95  = -417
    // jpeg_fine_grained_quality_level_94  = -418
    // jpeg_fine_grained_quality_level_93  = -419
    // jpeg_fine_grained_quality_level_92  = -420
    // jpeg_fine_grained_quality_level_91  = -421
    // jpeg_fine_grained_quality_level_90  = -422
    // jpeg_fine_grained_quality_level_89  = -423
    // jpeg_fine_grained_quality_level_88  = -424
    // jpeg_fine_grained_quality_level_87  = -425
    // jpeg_fine_grained_quality_level_86  = -426
    // jpeg_fine_grained_quality_level_85  = -427
    // jpeg_fine_grained_quality_level_84  = -428
    // jpeg_fine_grained_quality_level_83  = -429
    // jpeg_fine_grained_quality_level_82  = -430
    // jpeg_fine_grained_quality_level_81  = -431
    // jpeg_fine_grained_quality_level_80  = -432
    // jpeg_fine_grained_quality_level_79  = -433
    // jpeg_fine_grained_quality_level_78  = -434
    // jpeg_fine_grained_quality_level_77  = -435
    // jpeg_fine_grained_quality_level_76  = -436
    // jpeg_fine_grained_quality_level_75  = -437
    // jpeg_fine_grained_quality_level_74  = -438
    // jpeg_fine_grained_quality_level_73  = -439
    // jpeg_fine_grained_quality_level_72  = -440
    // jpeg_fine_grained_quality_level_71  = -441
    // jpeg_fine_grained_quality_level_70  = -442
    // jpeg_fine_grained_quality_level_69  = -443
    // jpeg_fine_grained_quality_level_68  = -444
    // jpeg_fine_grained_quality_level_67  = -445
    // jpeg_fine_grained_quality_level_66  = -446
    // jpeg_fine_grained_quality_level_65  = -447
    // jpeg_fine_grained_quality_level_64  = -448
    // jpeg_fine_grained_quality_level_63  = -449
    // jpeg_fine_grained_quality_level_62  = -450
    // jpeg_fine_grained_quality_level_61  = -451
    // jpeg_fine_grained_quality_level_60  = -452
    // jpeg_fine_grained_quality_level_59  = -453
    // jpeg_fine_grained_quality_level_58  = -454
    // jpeg_fine_grained_quality_level_57  = -455
    // jpeg_fine_grained_quality_level_56  = -456
    // jpeg_fine_grained_quality_level_55  = -457
    // jpeg_fine_grained_quality_level_54  = -458
    // jpeg_fine_grained_quality_level_53  = -459
    // jpeg_fine_grained_quality_level_52  = -460
    // jpeg_fine_grained_quality_level_51  = -461
    // jpeg_fine_grained_quality_level_50  = -462
    // jpeg_fine_grained_quality_level_49  = -463
    // jpeg_fine_grained_quality_level_48  = -464
    // jpeg_fine_grained_quality_level_47  = -465
    // jpeg_fine_grained_quality_level_46  = -466
    // jpeg_fine_grained_quality_level_45  = -467
    // jpeg_fine_grained_quality_level_44  = -468
    // jpeg_fine_grained_quality_level_43  = -469
    // jpeg_fine_grained_quality_level_42  = -470
    // jpeg_fine_grained_quality_level_41  = -471
    // jpeg_fine_grained_quality_level_40  = -472
    // jpeg_fine_grained_quality_level_39  = -473
    // jpeg_fine_grained_quality_level_38  = -474
    // jpeg_fine_grained_quality_level_37  = -475
    // jpeg_fine_grained_quality_level_36  = -476
    // jpeg_fine_grained_quality_level_35  = -477
    // jpeg_fine_grained_quality_level_34  = -478
    // jpeg_fine_grained_quality_level_33  = -479
    // jpeg_fine_grained_quality_level_32  = -480
    // jpeg_fine_grained_quality_level_31  = -481
    // jpeg_fine_grained_quality_level_30  = -482
    // jpeg_fine_grained_quality_level_29  = -483
    // jpeg_fine_grained_quality_level_28  = -484
    // jpeg_fine_grained_quality_level_27  = -485
    // jpeg_fine_grained_quality_level_26  = -486
    // jpeg_fine_grained_quality_level_25  = -487
    // jpeg_fine_grained_quality_level_24  = -488
    // jpeg_fine_grained_quality_level_23  = -489
    // jpeg_fine_grained_quality_level_22  = -490
    // jpeg_fine_grained_quality_level_21  = -491
    // jpeg_fine_grained_quality_level_20  = -492
    // jpeg_fine_grained_quality_level_19  = -493
    // jpeg_fine_grained_quality_level_18  = -494
    // jpeg_fine_grained_quality_level_17  = -495
    // jpeg_fine_grained_quality_level_16  = -496
    // jpeg_fine_grained_quality_level_15  = -497
    // jpeg_fine_grained_quality_level_14  = -498
    // jpeg_fine_grained_quality_level_13  = -499
    // jpeg_fine_grained_quality_level_12  = -500
    // jpeg_fine_grained_quality_level_11  = -501
    // jpeg_fine_grained_quality_level_10  = -502
    // jpeg_fine_grained_quality_level_9   = -503
    // jpeg_fine_grained_quality_level_8   = -504
    // jpeg_fine_grained_quality_level_7   = -505
    // jpeg_fine_grained_quality_level_6   = -506
    // jpeg_fine_grained_quality_level_5   = -507
    // jpeg_fine_grained_quality_level_4   = -508
    // jpeg_fine_grained_quality_level_3   = -509
    // jpeg_fine_grained_quality_level_2   = -510
    // jpeg_fine_grained_quality_level_1   = -511
    // jpeg_fine_grained_quality_level_0   = -512

    // jpeg_subsampling_16XChrominance = -763
    // jpeg_subsampling_8XChrominance  = -764
    // jpeg_subsampling_Grayscale      = -765
    // jpeg_subsampling_2XChrominance  = -766
    // jpeg_subsampling_4XChrominance  = -767
    // jpeg_subsampling_1XChrominance  = -768

    pub fn write(self: *const NativePayload, w: *std.Io.Writer, pixel_format: *const PixelFormat) !void {
        switch (self.*) {
            inline else => |payload| try payload.write(w, pixel_format),
        }
    }

    pub fn deinit(self: *NativePayload, allocator: std.mem.Allocator) void {
        switch (self.*) {
            inline else => |*payload| payload.deinit(allocator),
        }
    }
};

pub const CustomPayload = struct {
    type: TypeInt,
    vtable: *const VTable,

    pub const HandlerFn = CustomHandlerFn;

    pub const WriterError = std.Io.Writer.Error;

    pub const VTable = struct {
        write: *const fn (self: *const CustomPayload, w: *std.Io.Writer, pixel_format: *const PixelFormat) WriterError!void,
        destroy: *const fn (*CustomPayload, allocator: std.mem.Allocator) void,
    };

    pub inline fn write(self: *const CustomPayload, w: *std.Io.Writer, pixel_format: *const PixelFormat) !void {
        try self.vtable.write(self, w, pixel_format);
    }

    pub inline fn deinit(self: *CustomPayload, allocator: std.mem.Allocator) void {
        self.vtable.destroy(self, allocator);
    }
};

pub const CustomHandlerFn = fn (
    allocator: std.mem.Allocator,
    r: *std.Io.Reader,
    pixel_format: *const PixelFormat,
    rect: Rectangle,
    type: TypeInt,
    data: ?*anyopaque,
) Payload.ReadError!?*CustomPayload;

pub const Payload = union(enum) {
    native: NativePayload,
    custom: *CustomPayload,

    pub const Native = NativePayload;
    pub const Custom = CustomPayload;

    pub const Type = encoding.Type;
    pub const CustomHandlerFn = encoding.CustomHandlerFn;

    pub const Raw = RawPayload;

    pub const ReadError = error{ ParseError, UnsupportedEncodingType } || std.Io.Reader.Error || std.mem.Allocator.Error;

    pub const Iterator = struct {
        pos: u16 = 0,
        /// The number of payloads in the iterator.
        ///
        /// This is limited to 65535 by the rfb wire protocol.
        len: u16 = 0,
        vtable: *const VTable,

        pub const VTable = struct {
            next: *const fn (*Iterator) ReadError!Payload,
            destroy: *const fn (*Iterator, std.mem.Allocator) void,
        };

        pub const Slice = struct {
            payloads: [*]const Payload,

            interface: Iterator = .{
                .vtable = vtable,
            },

            pub const vtable = &VTable{
                .next = nextFn,
                .destroy = destroyFn,
            };

            pub fn init(payloads: []const Payload) Slice {
                return .{
                    .payloads = payloads.ptr,
                    .interface = Iterator{
                        .len = @intCast(payloads.len),
                        .vtable = vtable,
                    },
                };
            }

            fn nextFn(interface: *Iterator) ReadError!Payload {
                return @as(*Slice, @fieldParentPtr("interface", interface)).payloads[interface.pos];
            }

            fn destroyFn(interface: *Iterator, allocator: std.mem.Allocator) void {
                const self: *Slice = @fieldParentPtr("interface", interface);
                allocator.destroy(self);
                self.* = undefined;
            }
        };

        /// Creates a new iterator based on a slice of `Payload`s. Ownership of
        /// `payloads` is not transferred and remains the responsibility of the
        /// caller. However, the it is the caller's responsibility to call
        /// `deinit` on the returned iterator.
        ///
        /// Alternatively, call `Slice.init()` to allocate on the stack and pass
        /// a pointer to the `interface` field to the framebuffer update struct.
        pub fn slice(allocator: std.mem.Allocator, payloads: []const Payload) !*Iterator {
            const it = try allocator.create(Slice);
            it.* = .init(payloads);
            return &it.interface;
        }

        /// Get the next payload.
        ///
        /// Returned memory ownership is not transferred to the caller, do not
        /// call `deinit` on the returned payload.
        pub inline fn next(self: *Iterator) !?Payload {
            if (self.pos >= self.len) return null;
            defer self.pos += 1;

            return try self.vtable.next(self);
        }

        pub inline fn deinit(self: *Iterator, allocator: std.mem.Allocator) void {
            self.vtable.destroy(self, allocator);
        }
    };

    pub fn @"type"(self: *const Payload) Payload.Type {
        return switch (self.*) {
            .native => |msg| .{ .native = msg },
            .custom => |custom| .fromInt(custom.type),
        };
    }

    pub fn initNative(native: Payload.Native) Payload {
        return .{ .native = native };
    }

    pub fn initCustom(custom: *Payload.Custom) Payload {
        return .{ .custom = custom };
    }

    pub fn initRaw(raw: Raw) Payload {
        return initNative(.{ .raw = raw });
    }

    // Read the encoding payload from the framebuffer update message.
    //
    // `custom_encoding_handler` can be used to extend the set of supported
    // encodings. It is also possible to override the built-in implementations
    // of well-known encodings.
    pub fn read(
        allocator: std.mem.Allocator,
        r: *std.Io.Reader,
        pixel_format: *const PixelFormat,
        custom_encoding_handler: ?*const Payload.CustomHandlerFn,
        custom_encoding_handler_data: ?*anyopaque,
    ) ReadError!Payload {
        const rect: Rectangle = .{
            .x = try r.takeInt(u16, .big),
            .y = try r.takeInt(u16, .big),
            .w = try r.takeInt(u16, .big),
            .h = try r.takeInt(u16, .big),
        };

        const encoding_type = try r.takeInt(TypeInt, .big);
        if (custom_encoding_handler) |handler| {
            if (try handler(allocator, r, pixel_format, rect, encoding_type, custom_encoding_handler_data)) |payload| {
                return .{ .custom = payload };
            }
        }

        if (std.enums.fromInt(NativeType, encoding_type)) |native_type| {
            return .{
                .native = switch (native_type) {
                    inline else => |tag| @unionInit(
                        NativePayload,
                        @tagName(tag),
                        try .read(
                            allocator,
                            r,
                            pixel_format,
                            rect,
                        ),
                    ),
                },
            };
        }

        return error.UnsupportedEncodingType;
    }

    pub fn write(self: *const Payload, w: *std.Io.Writer, pixel_format: *const PixelFormat) !void {
        switch (self.*) {
            inline else => |payload| try payload.write(w, pixel_format),
        }
    }

    pub fn deinit(self: *Payload, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .native => |*native| native.deinit(allocator),
            .custom => |custom| custom.deinit(allocator),
        }
        self.* = undefined;
    }
};

pub const NativeType = std.meta.Tag(NativePayload);

pub const Type = union(enum) {
    native: NativeType,
    custom: TypeInt,

    pub const Int = TypeInt;

    pub const raw = fromEnum(.raw);

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
