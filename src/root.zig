const std = @import("std");

pub const Rectangle = @import("rectangle.zig");
pub const Point = @import("point.zig");
pub const Image = @import("image.zig");
pub const ColorMap = @import("color_map.zig");
pub const KeySym = @import("keysym.zig");

pub const Color = ColorMap.Color;

const pf = @import("pixel_format.zig");
pub const PixelFormat = pf.PixelFormat;
pub const TrueColorPixelFormat = pf.TrueColorPixelFormat;
pub const ColorMapPixelFormat = pf.ColorMapPixelFormat;

pub const encoding = @import("encoding.zig");
pub const NativeEncodingPayload = encoding.NativePayload;
pub const CustomEncodingPayload = encoding.CustomPayload;
pub const EncodingPayload = encoding.Payload;
pub const EncodingPayloadIterator = encoding.Payload.Iterator;
pub const NativeEncodingType = encoding.NativeType;
pub const EncodingType = encoding.Type;
pub const EncodingTypeInt = encoding.TypeInt;
pub const CustomEncodingHandlerFn = encoding.CustomHandlerFn;

pub const security = @import("security.zig");
pub const NativeSecurityType = security.NativeType;
pub const SecurityType = security.Type;
pub const SecurityTypeInt = security.TypeInt;
pub const NativeClientSecurity = security.client.Native;
pub const CustomClientSecurity = security.client.Custom;
pub const ClientSecurity = security.client.Security;
pub const NativeServerSecurity = security.server.Native;
pub const CustomServerSecurity = security.server.Custom;
pub const ServerSecurity = security.server.Security;
pub const NativeServerSecurityPayload = security.server.NativePayload;
pub const CustomServerSecurityPayload = security.server.CustomPayload;
pub const ServerSecurityPayload = security.server.Payload;

pub const message = @import("message.zig");
pub const ClientMessageType = message.client.Type;
pub const ClientMessageTypeInt = message.client.TypeInt;
pub const NativeClientMessage = message.client.Native;
pub const CustomClientMessage = message.client.Custom;
pub const ClientMessage = message.client.Message;
pub const SetPixelFormatClientMessage = message.client.SetPixelFormat;
pub const SetColorMapEntriesClientMessage = message.client.SetColorMapEntries;
pub const SetEncodingsClientMessage = message.client.SetEncodings;
pub const FramebufferUpdateRequestClientMessage = message.client.FramebufferUpdateRequest;
pub const KeyEventClientMessage = message.client.KeyEvent;
pub const PointerEventClientMessage = message.client.PointerEvent;
pub const CutTextClientMessage = message.client.CutText;
pub const CustomClientMessageHandlerFn = message.client.Custom.HandlerFn;
pub const ServerMessageType = message.server.Type;
pub const ServerMessageTypeInt = message.server.TypeInt;
pub const NativeServerMessage = message.server.Native;
pub const CustomServerMessage = message.server.Custom;
pub const ServerMessage = message.server.Message;
pub const FramebufferUpdateServerMessage = message.server.FramebufferUpdate;
pub const SetColorMapEntriesServerMessage = message.server.SetColorMapEntries;
pub const BellServerMessage = message.server.Bell;
pub const CutTextServerMessage = message.server.CutText;
pub const CustomServerMessageHandlerFn = message.server.Custom.HandlerFn;

pub const handshake = @import("handshake.zig");
pub const ProtocolVersion = handshake.ProtocolVersion;
pub const ServerInfo = handshake.ServerInfo;
pub const ClientOptions = handshake.ClientOptions;
pub const clientHandshake = handshake.client.handshake;
pub const serverHandshake = handshake.server.handshake;

pub const connection = @import("connection.zig");
pub const ClientConnection = connection.Client;
pub const ServerConnection = connection.Server;

const rc = @import("rc.zig");
pub const Rc = rc.Rc;
pub const ConstRc = rc.ConstRc;

pub const client = @import("client.zig");
pub const server = @import("server.zig");

test {
    std.testing.refAllDecls(@This());
}
