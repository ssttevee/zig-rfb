# zig-rfb

This is a hand-written implementation of the VNC/RFB protocol.
I made it for fun and learning purposes.
I plan to use it in my own projects in the future.
It is intentionally made to be thin and exposes the raw protocol primitives rather than abstracting everything away like other libraries.
This makes it much more flexible and allows easy implementation of custom encodings and security types.

The implementation is based on information from [rfc6143](https://datatracker.ietf.org/doc/html/rfc6143) as well as [this document](https://vncdotool.readthedocs.io/en/78/rfbproto.html) from [VNCDoTool](https://github.com/sibson/vncdotool) that has a bit of extra information about different versions.

## Using it in your own project

Run this command from your project folder

```sh
zig fetch --save git+https://github.com/ssttevee/zig-rfb.git#{optional commit hash to pin version}
```

Then add this snippet to your `build.zig` file

```zig
const rfb = b.dependency("rfb", .{
    .optimize = optimize,
    .target = target,
});

exe.root_module.addImport("rfb", rfb.module("rfb"));
```

## Sample programs

### chatterbox

[`chatterbox`](src/programs/chatterbox/main.zig) is a basic terminal-based server-client chat app that bastardizes the vnc protocol to demonstrate how to extend the library with custom message types.

### demoserver

[`demoserver`](src/programs/demoserver/main.zig) is a vnc server that renders a plasma effect based on [a tutorial by Lode Vandevenne](https://lodev.org/cgtutor/plasma.html).

![demoserver 1](docs/Screenshot%202025-09-24%20at%202.51.01 PM.png)

![demoserver 2](docs/Screenshot%202025-09-24%20at%204.51.35 PM.png)

### snapshot

[`snapshot`](src/programs/snapshot/main.zig) is a vnc client that saves the first frame to disk as a ppm file.

## Architecture

### Low Level Primitives

There are four main protocol elements: security, messages, encodings, and handshake.

Security, messages, and handshake are split up into client and server containers based on the side that is expected to consume it.
They can either be accessed on the root level with prefixed type names (i.e. `rfb.ClientSecurity` or `rfb.ServerSecurity`) or using the corresponding namespaces (i.e. `rfb.client.Security` or `rfb.server.Security`).

Since encodings only go one way (server to client), it is not split up and only consumed by `FramebufferUpdate`'s `read` and `write` methods.

There is an `Image` type that is basically just the raw pixel data with the pixel format attached for decoding and conversion purposes.

`PixelFormat` is implemented as a tagged union with `true_color` and `color_map` values.
The `ColorMap` is stored in `PixelFormat` as a ref counted smart pointer so it can be attached to `Image` without getting lost if the client changes the pixel format before the image is freed.

## Extensions

Only a small number of security, message, and encoding types are implemented.
However, every protocol element class can be extended with a callback function to customize how certain types numbers are handled without modifying the library code.
See [`chatterbox`](src/programs/chatterbox/main.zig) for an example of how to implement a custom message type.
