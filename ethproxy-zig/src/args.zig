const std = @import("std");

const EthArgs = struct { peer_iface: [:0]const u8, socket: [:0]const u8 };

pub fn ReadArgs() ?EthArgs {
    var args_it = std.process.args();
    // We are expecting two arguments: peer_iface and socket
    // first argument is the name of the program
    _ = args_it.next() orelse return null;
    const peer_iface: [:0]const u8 = args_it.next() orelse return null;
    const socket: [:0]const u8 = args_it.next() orelse return null;
    return .{
        .peer_iface = peer_iface,
        .socket = socket,
    };
}
