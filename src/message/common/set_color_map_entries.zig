const std = @import("std");
const root = @import("../../root.zig");

const ColorMap = root.ColorMap;

const SetColorMapEntries = @This();

color_map: ColorMap,

pub fn read(allocator: std.mem.Allocator, r: *std.Io.Reader) !SetColorMapEntries {
    _ = try r.takeByte(); // discard padding

    return .{
        .color_map = try ColorMap.read(allocator, r),
    };
}

pub fn write(self: *const SetColorMapEntries, w: *std.Io.Writer) !void {
    try w.writeAll(&.{
        0, // padding
    });
    try self.color_map.write(w);
}

pub fn deinit(self: *SetColorMapEntries, allocator: std.mem.Allocator) void {
    self.color_map.deinit(allocator);
    self.* = undefined;
}
