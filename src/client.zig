const message = @import("message/client.zig");
pub const MessageType = message.Type;
pub const MessageTypeInt = message.TypeInt;
pub const NativeMessage = message.Native;
pub const CustomMessage = message.Custom;
pub const Message = message.Message;
pub const CustomMessageHandlerFn = message.CustomHandlerFn;

pub const SetPixelFormatMessage = message.SetPixelFormat;
pub const SetColorMapEntriesMessage = message.SetColorMapEntries;
pub const SetEncodingsMessage = message.SetEncodings;
pub const FramebufferUpdateRequestMessage = message.FramebufferUpdateRequest;
pub const KeyEventMessage = message.KeyEvent;
pub const PointerEventMessage = message.PointerEvent;
pub const CutTextMessage = message.CutText;

const security = @import("security/client.zig");
pub const NativeSecurity = security.Native;
pub const CustomSecurity = security.Custom;
pub const Security = security.Security;

const common = @import("security/common.zig");
pub const NativeSecurityType = common.NativeSecurityType;
pub const SecurityType = common.SecurityType;
pub const SecurityTypeInt = common.SecurityTypeInt;

pub const handshake = @import("handshake/client.zig").handshake;
