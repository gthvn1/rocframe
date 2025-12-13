const std = @import("std");
const a = @import("args.zig");

pub fn main() !void {
    a.ReadArgs();
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
