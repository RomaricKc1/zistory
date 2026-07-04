//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const data_st = @import("data_structs");
const MainAppSt = data_st.MainAppSt;
const HistoryST = data_st.HistoryST;
const HistoryEntry = data_st.HistoryEntry;
const parse_hist_entry = data_st.parse_hist_entry;
const TimeSt = data_st.TimeSt;
const hist_reader = @import("hist_reader");
const rl = @import("raylib");
const rl_bar_graph = @import("rl_bar_graph");
const BarGraphDat = rl_bar_graph.BarGraphDat;
const rl_lists = @import("rl_lists");
const ListDat = rl_lists.ListDat;

const inputs = @import("inputs.zig");

const MAX_BYTES_PER_WORD = 256;

pub fn screen_post(opts: *MainAppSt) anyerror!void {
    switch (opts.game_screen) {
        .LOGO => {
            const text: [:0]const u8 = try format_cmd_text(opts.allocator, opts.command, "LOGO SCREEN");
            rl.drawText(text, 20, 20, 40, .light_gray);
            rl.drawText("WAIT for 2 SECONDS...", 290, 220, 20, .gray);
        },
        .ABOUT => {
            rl.drawRectangle(0, 0, opts.window_w, opts.window_h, .green);

            const text: [:0]const u8 = try format_cmd_text(opts.allocator, opts.command, "ABOUT screen");
            rl.drawText(text, 20, 20, 40, .dark_green);
            rl.drawText("ABOUT screen", 120, 220, 20, .dark_green);

            rl.drawText("ENTER or TAP -> MAIN", 10, 85, 10, .maroon);
        },
        .MAIN => {
            rl.drawRectangle(0, 0, opts.window_w, opts.window_h, .purple);
            var cmd_full: [:0]const u8 = undefined;

            if (opts.active_cmd) |this_idx| {
                try rl_bar_graph.bar_graph(
                    opts.allocator,
                    opts.bars_data.items[this_idx].*,
                    250,
                    100,
                    opts.window_w - 250,
                    opts.window_h - 100,
                    20,
                    opts.bars_data.items[this_idx].text_in_bin,
                );

                const curr_cmd_name = try format_cmd_text(
                    opts.allocator,
                    opts.bars_data.items[this_idx].name,
                    "",
                );
                rl.drawText(curr_cmd_name, 0, 55, 20, .white);
            }

            try rl_lists.lists(opts.allocator, opts.list_data.*, 0, 100, 250, opts.window_h - 250, 20);

            var text: [:0]const u8 = try format_cmd_text(opts.allocator, opts.command, "Current command: ");
            rl.drawText(text, 10, 30, 20, .maroon);

            cmd_full = try format_cmd_text(
                opts.allocator,
                opts.list_data.list_full.items[opts.list_data.active_idx],
                "Full cmd: ",
            );
            rl.drawText(cmd_full, 10, 5, 20, .blue);

            rl.drawText("ENTER or TAP -> ABOUT", 10, 85, 10, .maroon);

            const datetime: TimeSt = TimeSt.new(opts.sometime);
            const tmp_datetime = try std.fmt.allocPrint(opts.allocator, "{d}/{d}/{d}", .{
                datetime.datetime.day,
                datetime.datetime.month,
                datetime.datetime.year,
            });
            defer opts.allocator.free(tmp_datetime);

            text = try format_cmd_text(opts.allocator, tmp_datetime, "");
            const tmp_pos = if (opts.window_w > 140) opts.window_w - 140 else 0;
            rl.drawText(text, tmp_pos, 30, 20, .maroon);

            // current list widget idx and max value
            const cnt_info = try std.fmt.allocPrint(opts.allocator, "{d}/{d}", .{
                opts.list_data.active_idx + 1,
                opts.list_data.list_base.items.len,
            });
            defer opts.allocator.free(cnt_info);

            text = try format_cmd_text(opts.allocator, cnt_info, "");
            rl.drawText(text, tmp_pos, 60, 20, .white);
        },
    }
}

pub fn screen_pre(opts: *MainAppSt) anyerror!void {
    switch (opts.game_screen) {
        .LOGO => {
            opts.frame_counters.base += 1;

            // waits for 2 seconds (60 frames)
            if (opts.frame_counters.base > 60) {
                opts.frame_counters.base = 0;
                opts.game_screen = .MAIN;
            }
        },
        .ABOUT => {
            if (rl.isKeyPressed(.enter) or rl.isGestureDetected(.{ .tap = true })) {
                opts.game_screen = .MAIN;
            }

            // ctrl the data shown on the bar graph
            const ready_key_h = inputs.handle_inputs(opts, .h);
            if (ready_key_h) {
                // decreases the idx for the bars_data
                if (opts.active_cmd) |*current_active_cmd| {
                    if (current_active_cmd.* >= 1) {
                        current_active_cmd.* -= 1;
                    }
                }
            }

            const ready_key_l = inputs.handle_inputs(opts, .l);
            if (ready_key_l) {
                // increases the idx for the bars_data
                if (opts.active_cmd) |*current_active_cmd| {
                    if (opts.bars_data.items.len > (current_active_cmd.* + 1)) {
                        current_active_cmd.* += 1;
                    }
                }
            }
        },
        .MAIN => {
            if (rl.isKeyPressed(.enter) or rl.isGestureDetected(.{ .tap = true })) {
                opts.game_screen = .ABOUT;
            }

            const ready_key_j = inputs.handle_inputs(opts, .j);
            if (ready_key_j) {
                if (opts.list_data.active_idx < (opts.list_data.list_base.items.len - 1)) {
                    opts.list_data.active_idx += 1;
                }
            }

            const ready_key_k = inputs.handle_inputs(opts, .k);
            if (ready_key_k) {
                if (opts.list_data.active_idx > 0) {
                    opts.list_data.active_idx -= 1;
                }
            }

            const ready_key_h = inputs.handle_inputs(opts, .h);
            if (ready_key_h) {
                // decreases the idx for the bars_data
                if (opts.active_cmd) |*current_active_cmd| {
                    if (current_active_cmd.* >= 1) {
                        current_active_cmd.* -= 1;
                    }
                }
            }

            const ready_key_l = inputs.handle_inputs(opts, .l);
            if (ready_key_l) {
                // increases the idx for the bars_data
                if (opts.active_cmd) |*current_active_cmd| {
                    if (opts.bars_data.items.len > (current_active_cmd.* + 1)) {
                        current_active_cmd.* += 1;
                    }
                }
            }

            const active_cmd = opts.list_data.list_base.items[opts.list_data.active_idx];

            opts.command = active_cmd;
            opts.main_hist.set_curr_cmd(active_cmd);
            try opts.set_curr_cmd_and_update();
        },
    }
}

pub fn format_cmd_text(
    allocator: std.mem.Allocator,
    command: ?[]const u8,
    text: []const u8,
) ![:0]const u8 {
    if (command) |cmd| {
        const anytext = try std.fmt.allocPrintSentinel(allocator, "{s} {s}", .{ text, cmd }, 0);
        defer allocator.free(anytext);
        return rl.textFormat("%s", .{anytext.ptr});
    } else {
        return rl.textFormat("%s", .{text.ptr});
    }
}

pub fn run_auto(io: std.Io, allocator: std.mem.Allocator, app_ptr: **MainAppSt) !void {
    var app = app_ptr.*;

    var arr_l = std.ArrayList([]const u8).empty;
    defer arr_l.deinit(allocator);
    defer {
        for (arr_l.items) |this_item| {
            allocator.free(this_item);
        }
    }

    var hist_base = HistoryST.new(.{
        .allocator = allocator,
        .max_to_get = app.max_entries_to_get,
        .current_cmd = "zig",
        .nb_shown_entries = app.entries_shown_on_list,
    });
    app.main_hist = &hist_base;

    _ = try hist_reader.read_hist(io, allocator, &arr_l, .{
        .name = app.main_hist_file,
        .directory = ".",
        .delim = '\n',
        .entry_max_bytes = MAX_BYTES_PER_WORD,
        .number_of_entries = app.main_hist.max_to_get,
    });

    var entry_arl = std.ArrayList(HistoryEntry).empty;
    defer entry_arl.deinit(allocator);

    for (arr_l.items) |itm| {
        const hist_entr = parse_hist_entry(itm) catch |err| {
            std.debug.print("parse failed for -> \"{s}\": {any}\n", .{ itm, err });
            return err;
        };
        try entry_arl.append(allocator, hist_entr);
    }

    app.main_hist.set_hist_list(entry_arl);

    // list widget data from the HistoryST
    var list_data = try app.main_hist.get_list_cmds();
    defer list_data.cleanup();

    // bar graph data from the HistoryST
    var bar_week = try BarGraphDat.new(
        allocator,
        "weekly data",
        "week_title",
        .yellow,
        .blue,
        .white,
    );
    defer bar_week.cleanup();

    var bar_month = try BarGraphDat.new(
        allocator,
        "monthly data",
        "month_title",
        .yellow,
        .blue,
        .white,
    );
    defer bar_month.cleanup();

    app.bar_w_cfg = &bar_week;
    app.bar_m_cfg = &bar_month;

    // WEEKLY
    var time_span: data_st.TimeSpan = .WEEK;

    var x_axis_labels_w: []const []const u8 = undefined;
    defer allocator.free(x_axis_labels_w);

    var y_axis_val_w: []const i32 = undefined;
    defer allocator.free(y_axis_val_w);

    try app.main_hist.update_bar_graph_data(
        app.sometime,
        &x_axis_labels_w,
        &y_axis_val_w,
        app.bar_w_cfg,
        time_span,
    );

    // MONTHLY
    time_span = .MONTH;

    var x_axis_labels_m: []const []const u8 = undefined;
    defer allocator.free(x_axis_labels_m);

    var y_axis_val_m: []const i32 = undefined;
    defer allocator.free(y_axis_val_m);

    try app.main_hist.update_bar_graph_data(
        app.sometime,
        &x_axis_labels_m,
        &y_axis_val_m,
        app.bar_m_cfg,
        time_span,
    );

    var bars = std.ArrayList(*BarGraphDat).empty;
    defer bars.deinit(allocator);

    try bars.append(allocator, &bar_week);
    try bars.append(allocator, &bar_month);

    // wires up and run
    try app.set_bar_graph_data(bars);
    try app.set_list_data(&list_data);

    app.set_active_cmd(0);
    app.game_screen = .MAIN;

    // app.sometime = 1752496302; // 14th july

    try raylib_run(app);
}

pub fn raylib_run(opts: *MainAppSt) anyerror!void {

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = opts.window_w;
    const screenHeight = opts.window_h;

    rl.initWindow(screenWidth, screenHeight, "Zistory, your hist stats");
    defer rl.closeWindow();

    rl.setExitKey(.a); // actually q key
    rl.setTargetFPS(opts.fps);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detects window close button or a key
        // Update
        //----------------------------------------------------------------------------------
        try screen_pre(opts);
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);

        try screen_post(opts);
        //----------------------------------------------------------------------------------
    }
}

test "format_cmd_text" {
    const allocator = std.testing.allocator;

    var cmd: ?[]const u8 = null;
    var some: [:0]const u8 = try format_cmd_text(allocator, cmd, "LOGO SCREEN");
    try std.testing.expectEqualStrings("LOGO SCREEN", some);

    cmd = "zig";
    some = try format_cmd_text(allocator, cmd, "LOGO SCREEN");
    try std.testing.expectEqualStrings("LOGO SCREEN zig", some);
}
