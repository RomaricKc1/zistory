const std = @import("std");

const NB_ENTRY_READ_TYPE = u16;
const CONTINUE_READING = true;
const END_READING = false;
const ITERATION_MAX_MULTI_LINE_CMD = 20;

const ReadParams = struct {
    directory: []const u8,
    name: []const u8,
    delim: u8 = ' ',
    entry_max_bytes: u16,
    number_of_entries: NB_ENTRY_READ_TYPE,
};

pub fn read_file_alloc(allocator: std.mem.Allocator, file: std.fs.File, bytes: u64) ![]u8 {
    return try file.reader().readAllAlloc(allocator, @intCast(bytes));
}

pub fn read_file_delim(
    file: std.fs.File,
    into: *std.ArrayList(u8),
    delim: u8,
    max_size: u64,
) !bool {
    file.reader().readUntilDelimiterArrayList(into, delim, max_size) catch |err| {
        switch (err) {
            error.EndOfStream => {
                // std.debug.print("stop, no more stuff to read", .{});
                return END_READING;
            },
            else => {
                std.debug.print("error: -> {any}\n", .{err});
            },
        }
    };

    return CONTINUE_READING;
}

pub fn read_hist(
    anyalloc: std.mem.Allocator,
    arrlist: *std.ArrayList([]const u8),
    params: ReadParams,
) !NB_ENTRY_READ_TYPE {
    const cwd = std.fs.cwd();

    var hist_dir: std.fs.Dir = try cwd.openDir(params.directory, .{});
    defer hist_dir.close();

    const thefile = try hist_dir.openFile(params.name, .{ .mode = .read_only });
    defer thefile.close();
    try thefile.seekTo(0);

    var tmp_l = std.ArrayList(u8).init(anyalloc);
    defer tmp_l.deinit();

    var tmp_multi_l = std.ArrayList(u8).init(anyalloc);
    defer tmp_multi_l.deinit();

    try thefile.seekTo(0);

    const max_size: usize = params.entry_max_bytes;

    var anyslice: []u8 = undefined;
    var cnt: NB_ENTRY_READ_TYPE = 0;

    var curr_it: u8 = 0;

    // for (0..params.number_of_entries) |_| {
    for (0..std.math.maxInt(u64)) |_| {
        var stream_status = try read_file_delim(thefile, &tmp_l, params.delim, max_size);
        if (stream_status == END_READING) break;

        curr_it = 0;
        while (std.mem.endsWith(u8, tmp_l.items, "\\") and curr_it < ITERATION_MAX_MULTI_LINE_CMD) {
            curr_it += 1;
            // reads again until we don't have \ at the end
            stream_status = try read_file_delim(thefile, &tmp_multi_l, params.delim, max_size);
            // removes the \
            _ = tmp_l.pop();
            // todo: this may break a lot of stuff lol
            try tmp_l.appendSlice(" && ");
            try tmp_l.appendSlice(tmp_multi_l.items);
            // std.debug.print("multi-line here, next -> {s}, new {s}\n", .{ tmp_multi_l.items, tmp_l.items });
            if (stream_status == END_READING) break;
        }

        cnt += 1;
        anyslice = try tmp_l.toOwnedSlice();
        try arrlist.append(anyslice);
    }

    // reverses the arr to get last hist entries first
    try reverse_arr_list(anyalloc, arrlist);

    if (params.number_of_entries < cnt) {
        // remove those extra
        for (0..cnt - params.number_of_entries) |_| {
            const rm_ed = arrlist.pop();
            if (rm_ed) |that_val| {
                anyalloc.free(that_val);
            }
        }
        return params.number_of_entries;
    } else {
        return cnt;
    }
}

pub fn reverse_arr_list(
    anyalloc: std.mem.Allocator,
    input: *std.ArrayList([]const u8),
) !void {
    var tmp = std.ArrayList([]const u8).init(anyalloc);
    defer tmp.deinit();

    tmp = try input.clone();
    input.clearRetainingCapacity();

    for (tmp.items, 0..) |_, i| {
        const val = tmp.items[tmp.items.len - 1 - i];
        try input.append(val);
    }
    return;
}

test "reverse_arr_list" {
    const anyalloc = std.testing.allocator;

    var list = std.ArrayList([]const u8).init(anyalloc);
    defer list.deinit();

    try list.append("hello");
    try list.append("world");

    try reverse_arr_list(anyalloc, &list);

    try std.testing.expect(std.mem.eql(u8, "world", list.items[0]));
    try std.testing.expect(std.mem.eql(u8, "hello", list.items[1]));
}

test "read_hist" {
    const anyalloc = std.testing.allocator;

    var arr_l = std.ArrayList([]const u8).init(anyalloc);
    defer arr_l.deinit();
    defer {
        for (arr_l.items) |this_item| {
            anyalloc.free(this_item);
        }
    }
    const to_read_cnt = 24;
    const read_entries = try read_hist(anyalloc, &arr_l, .{
        .name = "build.zig.zon",
        .directory = ".",
        .delim = '\n',
        .entry_max_bytes = 256,
        .number_of_entries = to_read_cnt,
    });
    _ = read_entries; // autofix

    const expected =
        \\.fingerprint = 0xd7fbfdac645780a2,
    ;
    _ = expected; // autofix

    // list is reversed
    // disabled, because when .zon file is edied the test may fail
    // try std.testing.expectEqual(to_read_cnt, read_entries);
    // try std.testing.expect(std.mem.eql(u8, expected, arr_l.items[23][4..]));
}
