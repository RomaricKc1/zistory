const std = @import("std");
const build_options = @import("build_options");

const clap = @import("clap");
const data_st = @import("data_structs");
const MainAppSt = data_st.MainAppSt;
const HistoryST = data_st.HistoryST;
const HistoryEntry = data_st.HistoryEntry;
const zistory = @import("zistory");

const args = @import("args.zig");
const defaults = @import("defaults.zig");

var used_hist: []const u8 = undefined;

fn run(allocator: std.mem.Allocator, output: anytype) !void {
    // Parses command-line arguments
    const cli = try clap.parse(clap.Help, &args.params, args.parsers, .{ .allocator = allocator });
    defer cli.deinit();
    if (cli.args.help != 0) {
        try output.print("{s}\n", .{args.banner});
        try clap.help(output, clap.Help, &args.params, args.help_options);
        std.process.exit(0);
    } else if (cli.args.version != 0) {
        try output.print("{s} v{s}\n", .{ build_options.exe_name, build_options.version });
        std.process.exit(0);
    }

    // //////////////////////////////////////////////////////////////////////////////////////////////////
    var new_cfg: *MainAppSt = try allocator.create(MainAppSt);
    defer allocator.destroy(new_cfg);

    new_cfg.* = MainAppSt.new(.{
        .allocator = allocator,
        .fps = if (cli.args.fps) |fps| fps else defaults.fps,
        .window_h = if (cli.args.window_height) |window_h| window_h else defaults.window_height,
        .window_w = if (cli.args.window_width) |window_width| window_width else defaults.window_width,
        .max_entries_to_get = if (cli.args.cmd_cnt) |cnt| cnt else defaults.cmd_entries_cnt,
        .exit_key = if (cli.args.exit_key) |key| key else defaults.exit_key,
        .sometime = if (cli.args.time) |t| t else defaults.time_init,
        .main_hist_file = if (cli.args.history_file) |f| f else defaults.main_hist_file,
        .entries_shown_list = if (cli.args.elm_on_list_cnt) |cnt| cnt else defaults.max_entries_shown_list,
    });

    used_hist = new_cfg.main_hist_file;

    try zistory.run_auto(allocator, &new_cfg);

    return;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const deinit_stat = gpa.deinit();
        if (deinit_stat == .leak) @panic("Mem has leaked lol.");
    }

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    run(allocator, stdout) catch |err| {
        switch (err) {
            error.FileNotFound => try stderr.print(
                "An error has occurred: Your history \"{s}\" file doesn't exist :(\n",
                .{used_hist},
            ),
            else => try stderr.print("An error has occurred: {}\n", .{err}),
        }
    };

    try stdout.print("{s:*^50}\n", .{"Exit successful!"});
}

test "any" {
    try std.testing.expect(true);
}
