pub const client = @import("handshake/client.zig");
pub const server = @import("handshake/server.zig");

const common = @import("handshake/common.zig");

pub const ProtocolVersion = common.ProtocolVersion;
pub const ServerInfo = common.ServerInfo;
pub const ClientOptions = common.ClientOptions;
