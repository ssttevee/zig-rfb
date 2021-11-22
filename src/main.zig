const std = @import("std");
const net = std.net;

const rfb = @import("./rfb.zig");

// pub const io_mode = .evented;

pub fn main() anyerror!void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &general_purpose_allocator.allocator;

    var rfbServer = try rfb.RFBServer.init(allocator, .{
        .width = 640,
        .height = 480,
    }, "stevie zig-rfb");

    defer rfbServer.deinit();

    var server = net.StreamServer.init(.{});
    defer server.deinit();

    try server.listen(net.Address.parseIp("0.0.0.0", 5900) catch unreachable);
    std.debug.print("listening at {}\n", .{server.listen_address});

    const conn = try server.accept();
    std.debug.print("received connection from {}\n", .{conn.address});

    rfbServer.connect(conn.stream) catch |err| switch (err) {
        error.EndOfStream, error.Unexpected => {
            std.debug.print("connection closed\n", .{});
        },
        else => return err,
    };
}
