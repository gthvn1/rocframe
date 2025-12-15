const std = @import("std");
const posix = std.posix;

const a = @import("args.zig");
const FrameForge = @import("frameforge.zig").FrameForge;
const Veth = @import("veth.zig").Veth;

var keep_looping = std.atomic.Value(bool).init(true);

fn handleSigInt(sig_num: c_int) callconv(.c) void {
    _ = sig_num;
    keep_looping.store(false, .monotonic);
}

const PollAction = enum {
    timeout_reached,
    unknown,
    stdin_ready,
    veth_ready,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == std.heap.Check.ok);
    const allocator = gpa.allocator();

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

    // Connect to the frameforge server
    var server = FrameForge.init(args.socket) catch |e| {
        std.debug.print("Failed to create socket: {s}\n", .{@errorName(e)});
        std.process.exit(1);
    };
    defer server.deinit();

    // Connect to the Veth socket
    var veth = Veth.init(args.peer_iface) catch |e| {
        std.debug.print("Failed to connect to Veth {s}: {s}", .{ args.peer_iface, @errorName(e) });
        std.process.exit(1);
    };
    defer veth.deinit();

    // Manage user input
    var buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&buffer);
    const stdin = &stdin_reader.interface;

    std.debug.print("Ctrl-d to end\n", .{});
    std.debug.print("> ", .{});

    while (keep_looping.load(.monotonic)) {
        switch (wait(posix.STDIN_FILENO, veth.fd)) {
            .timeout_reached => continue,
            .stdin_ready => {
                if (stdin.takeDelimiterExclusive('\n')) |r| {
                    // need to toss the delimiter explicitly since we're not
                    // reading it. Otherwise we will loop forever
                    stdin.toss(1);

                    // Send it to server and print its response
                    try server.send(r);
                    const response = try server.read(allocator);
                    defer allocator.free(response);
                    std.debug.print("Response: {s}\n", .{response});
                } else |_| {
                    std.debug.print("end\n", .{});
                    std.process.exit(1);
                }
            },
            .veth_ready => {
                var buf: [2048]u8 = undefined;
                const n = posix.recv(veth.fd, &buf, 0) catch |e| {
                    std.debug.print("recv error: {s}\n", .{@errorName(e)});
                    // Print a new prompt
                    std.debug.print("> ", .{});
                    continue;
                };
                std.debug.print("Got frame: {d} bytes\n", .{n});
            },
            .unknown => {
                std.debug.print("What happens?\n", .{});
            },
        }

        // Print a new prompt
        std.debug.print("> ", .{});
    }

    std.debug.print("bye\n", .{});
}

fn wait(stdin: posix.fd_t, veth_fd: posix.fd_t) PollAction {
    var fds = [_]posix.pollfd{
        .{ .fd = stdin, .events = posix.POLL.IN, .revents = 0 },
        .{ .fd = veth_fd, .events = posix.POLL.IN, .revents = 0 },
    };

    // Wait 100ms
    const n = posix.poll(&fds, 100) catch unreachable;
    if (n == 0) return .timeout_reached;
    if ((fds[0].revents & posix.POLL.IN) != 0) return .stdin_ready;
    if ((fds[1].revents & posix.POLL.IN) != 0) return .veth_ready;
    return .unknown;
}
