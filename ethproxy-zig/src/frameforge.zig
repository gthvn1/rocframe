const std = @import("std");
const posix = std.posix;

pub const FrameForge = struct {
    fd: posix.fd_t,

    pub fn init(path: []const u8) !FrameForge {
        // Connect to frameforge server using Unix domain socket
        // https://medium.com/swlh/getting-started-with-unix-domain-sockets-4472c0db4eb1
        const frameforge_fd = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM, 0);

        var p: [108]u8 = [_]u8{0} ** 108;
        std.mem.copyForwards(u8, &p, path);

        const frameforge_addr = posix.sockaddr.un{
            .family = posix.AF.UNIX,
            .path = p,
        };

        try posix.connect(frameforge_fd, @ptrCast(&frameforge_addr), @sizeOf(posix.sockaddr.un));

        return .{
            .fd = frameforge_fd,
        };
    }

    pub fn deinit(self: FrameForge) void {
        posix.close(self.fd);
    }
};
