const server = @import("rfb/server.zig");

pub const RFBServer = server.RFBServer;

pub const PixelFormat = packed struct {
    bitsPerPixel: u8,
    depth: u8,
    bigEndianFlag: u8,
    trueColorFlag: u8,
    redMax: u16,
    greenMax: u16,
    blueMax: u16,
    redShift: u8,
    greenShift: u8,
    blueShift: u8,
    @"\\0 trailing padding 0": u8 = 0,
    @"\\0 trailing padding 1": u8 = 0,
    @"\\0 trailing padding 2": u8 = 0,
};

pub const defaultPixelFormat = PixelFormat{
    .bitsPerPixel = 32,
    .depth = 24,
    .bigEndianFlag = 0,
    .trueColorFlag = 1,
    .redMax = 8,
    .greenMax = 8,
    .blueMax = 8,
    .redShift = 0,
    .greenShift = 8,
    .blueShift = 16,
};

pub const ServerInit = packed struct {
    width: u16,
    height: u16,
    format: PixelFormat = defaultPixelFormat,
};

pub const SecurityType = enum(u8) {
    none = 1,
    vnc_authentication = 2,
};

pub const SecurityResult = enum(u32) {
    ok = 0,
    failed = 1,
};
