const std = @import("std");
const posix = std.posix;

const a = @import("args.zig");
const FrameForge = @import("frameforge.zig").FrameForge;

var keep_looping = std.atomic.Value(bool).init(true);

fn handleSigInt(sig_num: c_int) callconv(.c) void {
    _ = sig_num;
    keep_looping.store(false, .monotonic);
}

const PollAction = enum {
    timeout_reached,
    unknown,
    stdin_ready,
};

pub fn main() void {
    const args = a.ReadArgs() orelse {
        std.debug.print("Usage: ethproxy <peer_iface> <socket>\n", .{});
        std.process.exit(1);
    };

    std.debug.print("Peer Interface: {s}\n", .{args.peer_iface});
    std.debug.print("Socket: {s}\n", .{args.socket});

    // Change the ctrl-c action
    const action = posix.Sigaction{
        .flags = 0,
        .handler = .{ .handler = handleSigInt },
        .mask = posix.sigemptyset(),
    };
    posix.sigaction(posix.SIG.INT, &action, null);

    const server = FrameForge.init(args.socket) catch |e| {
        std.debug.print("Failed to create socket: {s}\n", .{@errorName(e)});
        std.process.exit(1);
    };
    defer server.deinit();

    // Manage user input
    var buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&buffer);
    const stdin = &stdin_reader.interface;

    std.debug.print("Ctrl-d to end\n", .{});
    std.debug.print("> ", .{});

    while (keep_looping.load(.monotonic)) {
        switch (wait(posix.STDIN_FILENO)) {
            .timeout_reached => continue,
            .stdin_ready => {
                if (stdin.takeDelimiterExclusive('\n')) |r| {
                    // need to toss the delimiter explicitly since we're not
                    // reading it
                    stdin.toss(1);
                    std.debug.print("You write <{s}>\n", .{r});
                    std.debug.print("> ", .{});
                } else |_| {
                    std.debug.print("end\n", .{});
                    std.process.exit(1);
                }
            },
            .unknown => {
                std.debug.print("What happens?\n", .{});
                continue;
            },
        }
    }

    std.debug.print("bye\n", .{});
}

fn wait(stdin: std.posix.fd_t) PollAction {
    var fds = [_]posix.pollfd{
        .{ .fd = stdin, .events = posix.POLL.IN, .revents = 0 },
    };

    // Wait 100ms
    const n = posix.poll(&fds, 100) catch unreachable;
    if (n == 0) return .timeout_reached;
    if ((fds[0].revents & posix.POLL.IN) != 0) return .stdin_ready;
    return .unknown;
}
