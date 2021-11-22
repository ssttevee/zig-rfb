const Point = @import("point.zig");

const Rectangle = @This();

x: usize,
y: usize,
w: usize,
h: usize,

pub fn init(x: usize, y: usize, w: usize, h: usize) Rectangle {
    return .{
        .x = x,
        .y = y,
        .w = w,
        .h = h,
    };
}

pub fn initTLBR(x1: usize, y1: usize, x2: usize, y2: usize) Rectangle {
    const t = @min(y1, y2);
    const l = @min(x1, x2);
    const b = @max(y1, y2);
    const r = @max(x1, x2);

    return .init(l, t, @intCast(r - l), @intCast(b - t));
}

pub fn initPoints(pt1: Point, pt2: Point) Rectangle {
    return .initTLBR(pt1.x, pt1.y, pt2.x, pt2.y);
}

pub fn topLeft(self: *const Rectangle) Point {
    return .init(self.x, self.y);
}

pub fn topRight(self: *const Rectangle) Point {
    return .init(self.x + self.w, self.y);
}

pub fn bottomLeft(self: *const Rectangle) Point {
    return .init(self.x, self.y + self.h);
}

pub fn bottomRight(self: *const Rectangle) Point {
    return .init(self.x + self.w, self.y + self.h);
}

pub fn intersection(self: Rectangle, other: Rectangle) Rectangle {
    return .initTLBR(
        @max(self.x, other.x),
        @max(self.y, other.y),
        @min(self.x + self.w, other.x + other.w),
        @min(self.y + self.h, other.y + other.h),
    );
}
