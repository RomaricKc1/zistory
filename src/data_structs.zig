const std = @import("std");
const parseInt = std.fmt.parseInt;

const hist_reader = @import("hist_reader");
const rl = @import("raylib");
const rl_bar_graph = @import("rl_bar_graph");
const BarGraphDat = rl_bar_graph.BarGraphDat;
const rl_lists = @import("rl_lists");
const ListDat = rl_lists.ListDat;

const ctime = @import("c");

pub const ts_type = ctime.time_t;
const TM_YEAR_INIT = 1900;
const FULL_DAY_TS = 86400;
const TM_MONTH_INIT = 1;

const Error = error{ TimestampStrParse, BaseCmdParse, FullCmdParse };

pub const TimeSpan = enum {
    WEEK,
    MONTH,
    YEAR,
};

/// main entry struct.
pub const MainAppSt = struct {
    /// the allocator
    allocator: std.mem.Allocator,
    /// the time from which to fetch data
    sometime: ts_type,
    /// window dimensions: height
    window_h: u16,
    /// window dimensions: width
    window_w: u16,
    /// current fps count
    fps: u16,
    /// the main history file
    main_hist_file: []const u8,
    /// exit key
    exit_key: u8,
    /// defines the number of entry to read
    max_entries_to_get: u16,
    /// number of entries show at a time on the list widget
    entries_shown_on_list: u8,
    /// the command
    command: ?[]const u8 = null,
    /// the current active bar data
    active_cmd: ?u32 = null,
    /// arbitrary value for inputs sampling
    times_key_hold: u16 = 8,
    /// series of counters used to count frames andd act
    frame_counters: FrameCounter = undefined,
    /// data related to the current command
    bars_data: std.ArrayList(*BarGraphDat) = undefined,
    /// data to be drawn in the List widget
    list_data: *ListDat = undefined,
    /// history content and all data
    main_hist: *HistoryST,
    /// bar x_axis, and y_axis data, week
    bar_w_cfg: *BarGraphDat = undefined,
    /// bar x_axis, and y_axis data, month
    bar_m_cfg: *BarGraphDat = undefined,

    /// type of stats to view
    game_screen: enum { LOGO, MAIN, ABOUT },

    pub fn new(
        opts: MainAppStMinimal,
    ) MainAppSt {
        const empty_frame_counter = FrameCounter{
            .j_down_key = 0,
            .k_up_key = 0,
            .base = 0,
            .l_right_key = 0,
            .h_left_key = 0,
        };
        var this_time: ts_type = @as(ts_type, @intCast(opts.sometime));
        if (this_time == 0) {
            this_time = TimeSt.get_now().ts;
        }

        const ret = MainAppSt{
            .allocator = opts.allocator,
            .window_h = opts.window_h,
            .window_w = opts.window_w,
            .command = "",
            .fps = opts.fps,
            .times_key_hold = 8,
            .frame_counters = empty_frame_counter,
            .bars_data = undefined,
            .active_cmd = 0,
            .list_data = undefined,
            .main_hist = undefined,
            .max_entries_to_get = opts.max_entries_to_get,
            .exit_key = opts.exit_key,
            .sometime = this_time,
            .entries_shown_on_list = opts.entries_shown_list,
            .main_hist_file = opts.main_hist_file,

            .game_screen = .LOGO,
        };
        return ret;
    }

    /// wires up the bars_list to the main struct
    pub fn set_bar_graph_data(
        self: *MainAppSt,
        bars_list: std.ArrayList(*BarGraphDat),
    ) !void {
        self.bars_data = bars_list;
    }

    /// wires up the widget list data to the main struct
    pub fn set_list_data(
        self: *MainAppSt,
        list_d: *ListDat,
    ) !void {
        self.list_data = list_d;
    }

    /// modifies the current active command from the bars_list ArrayList
    pub fn set_active_cmd(self: *MainAppSt, idx: ?u32) void {
        self.active_cmd = idx;
    }

    pub fn set_curr_cmd_and_update(self: *MainAppSt) !void {
        // frees old ones, and updates with the new active cmd
        self.allocator.free(self.main_hist.current_x_val_w.*);
        self.allocator.free(self.main_hist.current_y_val_w.*);

        self.allocator.free(self.main_hist.current_x_val_m.*);
        self.allocator.free(self.main_hist.current_y_val_m.*);

        try self.main_hist.update_bar_graph_data(
            self.sometime,
            self.main_hist.current_x_val_m,
            self.main_hist.current_y_val_m,
            self.bar_m_cfg,
            .MONTH,
        );
        try self.main_hist.update_bar_graph_data(
            self.sometime,
            self.main_hist.current_x_val_w,
            self.main_hist.current_y_val_w,
            self.bar_w_cfg,
            .WEEK,
        );
    }
};

/// the main history structure
pub const HistoryST = struct {
    /// defines the number of entry to read
    max_to_get: u16,
    /// number of entries show at a time on the list widget
    nb_shown_entries: u8,
    /// the list of all the entry that we read
    entries: std.ArrayList(HistoryEntry) = undefined,
    /// the current command
    current_cmd: []const u8,
    /// the allocator
    allocator: std.mem.Allocator,
    /// ptr to month values for y_axis
    current_y_val_m: *[]const i32 = undefined,
    /// ptr to month values for x_axis
    current_x_val_m: *[]const []const u8 = undefined,
    /// ptr to week values for y_axis
    current_y_val_w: *[]const i32 = undefined,
    /// ptr to week values for x_axis
    current_x_val_w: *[]const []const u8 = undefined,

    pub fn new(opts: HistoryST) HistoryST {
        const ret = HistoryST{
            .allocator = opts.allocator,
            .max_to_get = opts.max_to_get,
            .current_cmd = opts.current_cmd,
            .nb_shown_entries = opts.nb_shown_entries,
        };
        return ret;
    }

    pub fn set_hist_list(self: *HistoryST, entries: std.ArrayList(HistoryEntry)) void {
        self.entries = entries;
    }

    pub fn set_curr_cmd(self: *HistoryST, cmd: []const u8) void {
        self.current_cmd = cmd;
    }

    pub fn update_bar_graph_data(
        self: *HistoryST,
        sometime: ts_type,
        x_vals: *[]const []const u8,
        y_vals: *[]const i32,
        bar_cfg: ?*BarGraphDat,
        span: TimeSpan,
    ) !void {
        x_vals.* = try self.get_bar_graph_x(TimeSt.new(sometime), span);
        y_vals.* = try self.get_bar_graph_y(TimeSt.new(sometime), span);

        switch (span) {
            .WEEK => {
                self.current_x_val_w = x_vals;
                self.current_y_val_w = y_vals;

                if (bar_cfg) |found| {
                    found.remove_elms();
                    try found.set_xlist(self.current_x_val_w.*);
                    try found.set_ylist(self.current_y_val_w.*);
                }
            },
            .MONTH => {
                self.current_x_val_m = x_vals;
                self.current_y_val_m = y_vals;

                if (bar_cfg) |found| {
                    found.remove_elms();
                    try found.set_xlist(self.current_x_val_m.*);
                    try found.set_ylist(self.current_y_val_m.*);
                }
            },
            else => {},
        }
    }

    // counts how many times a certain cmd has been recorded
    pub fn count_this_cmd(self: *HistoryST, time_range: DateTimeRange) u16 {
        var cnt: u16 = 0;
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.base, self.current_cmd)) {
                if (datetime_in_period_incl(entry.time_st, time_range)) {
                    cnt += 1;
                }
            }
        }
        return cnt;
    }

    pub fn get_bar_graph_x(
        self: *HistoryST,
        current_date: TimeSt,
        span: TimeSpan,
    ) ![]const []const u8 {
        var span_cnt: u16 = undefined;
        switch (span) {
            .MONTH => span_cnt = 31,
            .WEEK => span_cnt = 7,
            else => unreachable,
        }

        var arr: [][]const u8 = try self.allocator.alloc([]const u8, @intCast(span_cnt));

        const days_list = try get_n_days_before_incl(self.allocator, current_date, span_cnt);
        defer self.allocator.free(days_list);

        // now loops here, and sets the arr_x with the day of the week txt val
        for (days_list, 0..) |a_day, idx| {
            arr[span_cnt - 1 - idx] = week_day_to_str(a_day.datetime.day_week);
        }

        return arr;
    }

    pub fn get_bar_graph_y(self: *HistoryST, current_date: TimeSt, span: TimeSpan) ![]const i32 {
        var span_cnt: u16 = undefined;
        switch (span) {
            .MONTH => span_cnt = 31,
            .WEEK => span_cnt = 7,
            else => unreachable,
        }

        var arr: []i32 = try self.allocator.alloc(i32, @intCast(span_cnt));

        // the list of days that we want the cmd cnt value
        const days_list = try get_n_days_before_incl(self.allocator, current_date, span_cnt);
        defer self.allocator.free(days_list);

        for (days_list, 0..) |a_day, idx| {
            const this_range = DateTimeRange{ .before = a_day, .after = a_day };

            const this_cnt = self.count_this_cmd(this_range);
            arr[span_cnt - 1 - idx] = this_cnt;
        }

        return arr;
    }

    // list widget data
    pub fn get_list_cmds(self: *HistoryST) !ListDat {
        var list_d: ListDat = try ListDat.new(
            self.allocator,
            "name",
            "title",
            .yellow,
            .dark_blue,
            .white,
            self.nb_shown_entries,
        );

        for (self.entries.items) |entry| {
            try list_d.list_base.append(self.allocator, entry.base);
            try list_d.list_full.append(self.allocator, entry.full);
        }

        return list_d;
    }
};

/// Datetime related stuff,
/// using ctime from clang time.h
pub const TimeSt = struct {
    /// the datetime info it was registered
    datetime: DateTime,
    /// the timestamp it was registered
    ts: ts_type,

    pub fn new(ts: ts_type) TimeSt {
        var this_time: ts_type = ts;
        const timeinfo = ctime.localtime(&this_time);
        // const date = ctime.asctime(timeinfo);
        // std.debug.print("{any}, date -> {s}, {d}\n", .{ timeinfo, date, timeinfo.*.tm_year });

        const day = timeinfo.*.tm_mday;
        const month = timeinfo.*.tm_mon + TM_MONTH_INIT;
        const year = timeinfo.*.tm_year + TM_YEAR_INIT;
        const day_week = timeinfo.*.tm_wday;
        const offset = timeinfo.*.tm_gmtoff;

        const ret = TimeSt{
            .datetime = .{
                .day = day,
                .month = month,
                .year = year,
                .day_week = day_week,
                .offset = offset,
            },
            .ts = ts,
        };
        return ret;
    }

    pub fn get_now() TimeSt {
        var this_time: ts_type = undefined;
        _ = ctime.time(&this_time);
        const timeinfo = ctime.localtime(&this_time);

        const day = timeinfo.*.tm_mday;
        const month = timeinfo.*.tm_mon + TM_MONTH_INIT;
        const year = timeinfo.*.tm_year + TM_YEAR_INIT;
        const day_week = timeinfo.*.tm_wday;
        const offset = timeinfo.*.tm_gmtoff;

        const ret = TimeSt{
            .datetime = .{
                .day = day,
                .month = month,
                .year = year,
                .day_week = day_week,
                .offset = offset,
            },
            .ts = this_time,
        };
        return ret;
    }
};

/// used to handle inputs and other stuff
pub const FrameCounter = struct {
    j_down_key: u64 = 0,
    k_up_key: u64 = 0,
    l_right_key: u64 = 0,
    h_left_key: u64 = 0,
    base: u64 = 0,
};

/// Minimal used to make function param clear when passing args
pub const MainAppStMinimal = struct {
    allocator: std.mem.Allocator,
    window_w: u16,
    window_h: u16,
    fps: u16,
    max_entries_to_get: u16,
    exit_key: u8,
    sometime: u64,
    entries_shown_list: u8,
    main_hist_file: []const u8,
};

/// datetime struct
pub const DateTime = struct {
    /// the day it was registered
    day: c_int,
    /// the month it was registered
    month: c_int,
    /// the year it was registered
    year: c_int,
    /// the week day
    day_week: c_int,
    /// offset utc
    offset: c_long,
};

/// simple datetime range hodling 2 timeStructs
pub const DateTimeRange = struct {
    /// the date before
    before: TimeSt,
    /// the date after
    after: TimeSt,
};

/// an history entry that get's parsed from the history file
/// e.g.: ': 1752241336:0;zig build test'
/// 11/6/2025 <- the date, cmd base: zig, full zig build test
pub const HistoryEntry = struct {
    /// the name of the command
    base: []const u8,
    /// the full command with parameters and such
    full: []const u8,
    /// its time related stuff
    time_st: TimeSt,

    pub fn new(
        opts: HistoryEntry,
    ) HistoryEntry {
        const ret = HistoryEntry{
            .base = opts.base,
            .full = opts.full,
            .time_st = opts.time_st,
        };
        return ret;
    }
};

// //////////////////////////////////////////////////////////////////////////////////////////
// other funtions
pub fn return_begin_day(time: TimeSt) ts_type {
    var this_time: ts_type = time.ts;
    const timeinfo = ctime.localtime(&this_time);

    const hour = timeinfo.*.tm_hour;
    const min = timeinfo.*.tm_min;
    const scs = timeinfo.*.tm_sec;

    var ret: ts_type = time.ts;

    if (hour > 0) {
        ret -= hour * 60 * 60;
    }
    if (min > 0) {
        ret -= min * 60;
    }
    if (scs > 0) {
        ret -= scs;
    }
    return ret;
}

/// ignores the hours, min and secs
pub fn datetime_in_period_incl(timestamp_day: TimeSt, ts_range: DateTimeRange) bool {
    const begin_day = return_begin_day(timestamp_day);
    const begin_before = return_begin_day(ts_range.before);
    const begin_after = return_begin_day(ts_range.after);

    if (begin_day <= begin_before and begin_day >= begin_after) {
        // after <= day <= before
        return true;
    }

    return false;
}

pub fn get_n_days_before_incl(allocator: std.mem.Allocator, timestamp: TimeSt, n: u16) ![]TimeSt {
    const result: []TimeSt = try allocator.alloc(TimeSt, n);

    for (0..n) |idx| {
        result[idx] = TimeSt.new(timestamp.ts - @as(ts_type, @intCast(FULL_DAY_TS * idx)));
    }

    return result;
}

pub fn get_current_datetime() TimeSt {
    return TimeSt.get_now();
}

pub fn week_day_to_str(wday: c_int) []const u8 {
    switch (wday) {
        1 => return "Mon",
        2 => return "Tue",
        3 => return "Wed",
        4 => return "Thu",
        5 => return "Fri",
        6 => return "Sat",
        0 => return "Sun",
        else => unreachable,
    }
}
/// simple function to exit quickly
pub fn exit_here() void {
    std.process.exit(0);
}

/// parses the str from zsh hist into a nice formatted struct
pub fn parse_hist_entry(entry_str: []const u8) !HistoryEntry {
    var it_entry = std.mem.splitAny(u8, entry_str, ":");
    _ = it_entry.next();

    var timestamp_str: []const u8 = it_entry.next() orelse {
        std.debug.print("error: can't get timestamp from the entry \"{s}\"\n", .{entry_str});
        return Error.TimestampStrParse;
    };

    timestamp_str = timestamp_str[1..]; // removes trailing space char
    const cmd_tmp: []const u8 = it_entry.next() orelse {
        return Error.FullCmdParse;
    };

    var it_cmd_full = std.mem.splitAny(u8, cmd_tmp, ";");
    _ = it_cmd_full.next();

    const cmd_full: []const u8 = it_cmd_full.next() orelse {
        std.debug.print("error: can't get full base from.\n", .{});
        return Error.FullCmdParse;
    };

    var it_cmd = std.mem.splitAny(u8, cmd_full, " ");
    const cmd_base: []const u8 = it_cmd.next() orelse {
        std.debug.print("error: can't get full base from.\n", .{});
        return Error.BaseCmdParse;
    };

    const base = 10;
    const timestamp: u64 = parseInt(u64, timestamp_str, base) catch |err| {
        std.debug.print("parse int failed for -> \"{s}\": {any}\n", .{ timestamp_str, err });
        return err;
    };

    return HistoryEntry{
        .base = cmd_base,
        .full = cmd_full,
        .time_st = TimeSt.new(@as(ts_type, @intCast(timestamp))),
    };
}

// ////////////////////////////////////////////////////////////////////////////////////////////////////////
// tests here
test "datetime_in_period_incl" {
    var day = TimeSt.new(1752109200);
    const range = DateTimeRange{ .before = TimeSt.new(1752109200), .after = TimeSt.new(1751331600) };

    try std.testing.expectEqual(true, datetime_in_period_incl(day, range));

    day = TimeSt.new(1751331600);
    try std.testing.expectEqual(true, datetime_in_period_incl(day, range));

    day = TimeSt.new(1752009200);
    try std.testing.expectEqual(true, datetime_in_period_incl(day, range));

    day = TimeSt.new(1751331599);
    try std.testing.expectEqual(true, datetime_in_period_incl(day, range));

    try std.testing.expectEqual(true, datetime_in_period_incl(day, DateTimeRange{
        .before = day,
        .after = day,
    }));

    // shoudln't
    day = TimeSt.new(1749603601);
    try std.testing.expectEqual(false, datetime_in_period_incl(day, range));
}

test "parse_hist_entry" {
    const input = ": 1752241336:0;zig build test";
    const hist_entry = try parse_hist_entry(input);

    try std.testing.expectEqualStrings("zig", hist_entry.base);
    try std.testing.expectEqualStrings("zig build test", hist_entry.full);

    try std.testing.expectEqual(2025, hist_entry.time_st.datetime.year);
    try std.testing.expectEqual(7, hist_entry.time_st.datetime.month);
    try std.testing.expectEqual(11, hist_entry.time_st.datetime.day);
}

test "full e.g. read real hist from file and check widget data" {
    const io: std.Io = std.testing.io;
    const anyalloc = std.testing.allocator;

    var arr_l = std.ArrayList([]const u8).empty;
    defer arr_l.deinit(anyalloc);
    defer {
        for (arr_l.items) |this_item| {
            anyalloc.free(this_item);
        }
    }

    var hist_base = HistoryST.new(.{
        .allocator = anyalloc,
        .max_to_get = 10,
        .current_cmd = "gcc",
        .nb_shown_entries = 4,
    });

    const nb_entries_read = try hist_reader.read_hist(io, anyalloc, &arr_l, .{
        .name = "test_hist",
        .directory = "./testsample",
        .delim = '\n',
        .entry_max_bytes = 256,
        .number_of_entries = hist_base.max_to_get,
    });

    var entry_arl = std.ArrayList(HistoryEntry).empty;
    defer entry_arl.deinit(anyalloc);

    // std.debug.print("\n", .{});
    for (arr_l.items) |itm| {
        if (!std.mem.eql(u8, itm, "")) {
            // std.debug.print("actual entries to parse: {s}\n", .{itm});
            const hist_entr = try parse_hist_entry(itm);
            try entry_arl.append(anyalloc, hist_entr);
        }
    }

    hist_base.set_hist_list(entry_arl);

    // /////////////////////////////////////////////////////////////////////
    // bar graph data from the HistoryST
    var bar0 = try BarGraphDat.new(anyalloc, "name", "title", .yellow, .blue, .white);
    defer bar0.cleanup();

    const sometime: ts_type = 1752496302; // 14th july

    // .WEEK span
    var x_axis_labels: []const []const u8 = undefined;
    defer anyalloc.free(x_axis_labels);

    var y_axis_val: []const i32 = undefined;
    defer anyalloc.free(y_axis_val);

    var some_bars_data = std.ArrayList(*BarGraphDat).empty;
    defer some_bars_data.deinit(anyalloc);

    // sets the values for the bar graph
    try hist_base.update_bar_graph_data(
        sometime,
        &x_axis_labels,
        &y_axis_val,
        null,
        .WEEK,
    );

    try bar0.set_xlist(hist_base.current_x_val_w.*);
    try bar0.set_ylist(hist_base.current_y_val_w.*);

    try some_bars_data.append(anyalloc, &bar0);

    // .WEEK span
    inline for (some_bars_data.items[0].y_list.items, &.{ 1, 0, 1, 1, 0, 0, 0 }) |val1, val2| {
        try std.testing.expectEqual(val1, val2);
    }

    inline for (
        &.{ "Tue", "Wed", "Thu", "Fri", "Sat", "Sun", "Mon" },
        some_bars_data.items[0].x_list.items,
    ) |val1, val2| {
        try std.testing.expectEqualStrings(val1, val2);
    }

    // /////////////////////////////////////////////////////////////////////
    // list widget data from the HistoryST
    var list_data = try hist_base.get_list_cmds();
    defer list_data.cleanup();

    try std.testing.expectEqual(nb_entries_read, hist_base.entries.items.len);

    // the list is reversed
    // .WEEK span
    inline for (
        &.{ "zig", "gcc", "img", "lazygit", "clear", "python3", "gcc", "gcc" },
        list_data.list_base.items,
    ) |val1, val2| {
        try std.testing.expectEqualStrings(val1, val2);
    }
}

test "TimeSt" {
    const time_st = TimeSt.new(1752241336);
    try std.testing.expectEqual(
        time_st,
        TimeSt{
            .datetime = .{
                .day = 11,
                .month = 7,
                .year = 2025,
                .day_week = 5,
                .offset = time_st.datetime.offset,
            },
            .ts = 1752241336,
        },
    );

    const wday_str = week_day_to_str(time_st.datetime.day_week);
    try std.testing.expectEqual("Fri", wday_str);
}

test "get_n_days_before" {
    const allocator = std.testing.allocator;

    const expected: []const TimeSt = &[_]TimeSt{
        TimeSt.new(1752493179),
        TimeSt.new(1752406779),
        TimeSt.new(1752320379),
    };

    const res = try get_n_days_before_incl(allocator, TimeSt.new(1752493179), 3);
    defer allocator.free(res);

    for (expected, res) |exp, got| {
        try std.testing.expectEqual(exp.datetime.year, got.datetime.year);
        try std.testing.expectEqual(exp.datetime.month, got.datetime.month);
        try std.testing.expectEqual(exp.datetime.day, got.datetime.day);
    }
}

test "get_current_timestamp" {
    // const any = get_current_datetime();
    // std.debug.print("{any}", .{any});
}

test "return_begin_day" {
    const a_time: ts_type = 1752237102;
    const datetime = TimeSt.new(a_time);

    const res = 1752192000 - datetime.datetime.offset;
    const found = return_begin_day(TimeSt.new(a_time));
    try std.testing.expectEqual(res, found);
}

// // TODO:
// test "exit_here" {
//     exit_here();
//     unreachable; // lol
// }
