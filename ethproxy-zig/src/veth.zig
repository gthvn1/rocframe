const std = @import("std");
const posix = std.posix;

// TODO: if we want to remove the C dependency we can probably pass the index
//       as parameter when calling the binary. Or at least, as the network is setup
//       before calling the proxy we can pass the result of `ip -j a` and parse the
//       json to find the index.
pub const Veth = struct {
    fd: posix.fd_t,

    pub fn init(name: [:0]const u8) !Veth {
        // man 7 packet
        const protocol = std.mem.nativeToBig(u16, std.os.linux.ETH.P.ALL);
        const veth_fd = try posix.socket(posix.AF.PACKET, posix.SOCK.RAW, protocol);

        const idx = std.c.if_nametoindex(name);
        if (idx == 0) return error.InterfaceNotFound;

        std.debug.print("{s} interface = {d}\n", .{ name, idx });

        const veth_addr = posix.sockaddr.ll{
            .family = posix.AF.PACKET,
            .protocol = protocol,
            .ifindex = idx,
            .hatype = 0,
            .pkttype = 0,
            .halen = 0,
            .addr = [_]u8{0} ** 8,
        };

        try posix.bind(veth_fd, @ptrCast(&veth_addr), @sizeOf(posix.sockaddr.ll));

        return .{
            .fd = veth_fd,
        };
    }

    pub fn deinit(self: *Veth) void {
        posix.close(self.fd);
    }
};
