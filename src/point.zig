const Point = @This();

x: usize,
y: usize,

pub const zero = init(0, 0);

pub fn init(x: usize, y: usize) Point {
    return Point{ .x = x, .y = y };
}
