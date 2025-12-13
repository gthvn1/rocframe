const std = @import("std");
const a = @import("args.zig");

pub fn main() !void {
    const args = a.ReadArgs() orelse {
        std.debug.print("Usage: ethproxy <peer_iface> <socket>\n", .{});
        std.process.exit(1);
    };

    std.debug.print("Peer Interface: {s}\n", .{args.peer_iface});
    std.debug.print("Socket: {s}\n", .{args.socket});
}
