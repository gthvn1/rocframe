const std = @import("std");

pub fn ReadArgs() void {
    var args_it = std.process.args();
    while (args_it.next()) |arg| {
        std.debug.print("-> {s}\n", .{arg});
    }
}
