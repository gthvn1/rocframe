const std = @import("std");
const a = @import("args.zig");

var quit_loop = std.atomic.Value(bool).init(false);

fn handleSigInt(sig_num: c_int) callconv(.c) void {
    _ = sig_num;
    quit_loop.store(true, .monotonic);
}

pub fn main() !void {
    const args = a.ReadArgs() orelse {
        std.debug.print("Usage: ethproxy <peer_iface> <socket>\n", .{});
        std.process.exit(1);
    };

    std.debug.print("Peer Interface: {s}\n", .{args.peer_iface});
    std.debug.print("Socket: {s}\n", .{args.socket});

    // Change the ctrl-c action
    const action = std.posix.Sigaction{
        .flags = 0,
        .handler = .{ .handler = handleSigInt },
        .mask = std.posix.sigemptyset(),
    };
    std.posix.sigaction(std.posix.SIG.INT, &action, null);

    // Read user input
    var buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&buffer);
    const stdin = &stdin_reader.interface;

    std.debug.print("Ctrl-d to end\n", .{});
    std.debug.print("> ", .{});

    while (stdin.takeDelimiterExclusive('\n')) |r| {
        // need to toss the delimiter explicitly since we're not reading it
        stdin.toss(1);

        std.debug.print("You write <{s}>\n", .{r});
        // Should we continue
        if (quit_loop.load(.monotonic)) {
            std.debug.print("bye", .{});
            break;
        }
        std.debug.print("> ", .{});
    } else |_| {
        std.debug.print("end", .{});
        std.process.exit(1);
    }
}
