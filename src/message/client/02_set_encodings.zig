const std = @import("std");
const root = @import("../../root.zig");

const EncodingType = root.EncodingType;

const SetEncodings = @This();

encodings: []const EncodingType,

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader) !SetEncodings {
    _ = try r.takeByte(); // discard padding

    const number_of_encodings = try r.takeInt(u16, .big);

    const encodings = try allocator.alloc(EncodingType, number_of_encodings);
    errdefer allocator.free(encodings);

    for (0..number_of_encodings) |i| {
        encodings[i] = .fromInt(try r.takeInt(EncodingType.Int, .big));
    }

    return SetEncodings{
        .encodings = encodings,
    };
}

pub fn write(self: *const SetEncodings, w: *std.Io.Writer) !void {
    try w.writeAll(&.{
        0, // padding
    });
    try w.writeInt(u16, @truncate(self.encodings.len), .big);
    try w.writeSliceEndian(i32, @ptrCast(self.encodings), .big);
}

pub fn deinit(self: *SetEncodings, allocator: std.mem.Allocator) void {
    allocator.free(self.encodings);
    self.* = undefined;
}
