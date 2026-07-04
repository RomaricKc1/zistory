const std = @import("std");
const builtin = @import("builtin");

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

pub fn push_cpy(allocator: std.mem.Allocator, into: *std.ArrayList([]const u8), src: []const u8) !void {
    const len = src.len;
    const buf = try allocator.alloc(u8, len);

    std.mem.copyForwards(u8, buf, src);
    // std.debug.print("pushing -> {s}\n", .{buf});
    try into.append(allocator, buf[0..len]);
}

pub fn read_file_delim(
    file: std.Io.File,
    into: *std.ArrayList([]const u8),
    delim: u8,
    io: std.Io,
    allocator: std.mem.Allocator,
) !u16 {
    var cnt: NB_ENTRY_READ_TYPE = 0;
    var curr_it: u8 = 0;

    var buf: [8192]u8 = undefined;
    var reader: std.Io.File.Reader = file.reader(io, &buf);

    var tmp_l = std.ArrayList(u8).empty;
    defer tmp_l.deinit(allocator);

    var all_elements = std.ArrayList([]const u8).empty;
    defer all_elements.deinit(allocator);

    while (try reader.interface.takeDelimiter(delim)) |line| {
        try all_elements.append(allocator, line);
    }

    var next_line: []const u8 = undefined;
    var this_line: []const u8 = undefined;

    var used_multiline: bool = false;
    var idx: usize = 0;
    var skip_next_line: bool = false;

    for (all_elements.items, 0..) |got, i| {
        idx = i + curr_it;
        this_line = got;

        if (skip_next_line) {
            // std.debug.print("skipping [{s}]\n", .{next_line});
            continue;
        }
        next_line = &.{};

        if (idx < all_elements.items.len - 1) {
            next_line = all_elements.items[idx + 1];
        } else {
            next_line = "";
        }

        while (std.mem.endsWith(u8, this_line, "\\") and curr_it < ITERATION_MAX_MULTI_LINE_CMD) {
            curr_it += 1;
            used_multiline = true;

            if (!std.mem.eql(u8, this_line, next_line)) {
                try tmp_l.appendSlice(allocator, this_line[0 .. this_line.len - 1]);
                try tmp_l.appendSlice(allocator, " && ");
            }

            if (std.mem.endsWith(u8, next_line, "\\")) {
                try tmp_l.appendSlice(allocator, next_line[0 .. next_line.len - 1]);
                try tmp_l.appendSlice(allocator, " && ");
            }

            if (idx < all_elements.items.len - (curr_it + 1)) {
                next_line = all_elements.items[idx + curr_it + 1];
            } else {
                next_line = "";
            }
            this_line = next_line;

            // if next line is the end, just add it
            if (!std.mem.endsWith(u8, next_line, "\\")) {
                if (!std.mem.eql(u8, next_line, "")) {
                    // try tmp_l.appendSlice(allocator, " && ");
                    try tmp_l.appendSlice(allocator, next_line);
                }
                skip_next_line = true;
            }
        }

        if (used_multiline) {
            try push_cpy(allocator, into, tmp_l.items);
            used_multiline = false;
        } else {
            try push_cpy(allocator, into, got);
        }
        cnt += 1;
    }

    return cnt;
}

pub fn read_hist(
    io: std.Io,
    anyalloc: std.mem.Allocator,
    arrlist: *std.ArrayList([]const u8),
    params: ReadParams,
) !NB_ENTRY_READ_TYPE {
    const cwd = std.Io.Dir.cwd();
    var hist_dir: std.Io.Dir = try cwd.openDir(io, params.directory, .{});
    defer hist_dir.close(io);

    const thefile = try hist_dir.openFile(io, params.name, .{ .mode = .read_only });
    defer thefile.close(io);

    const cnt = try read_file_delim(
        thefile,
        arrlist,
        params.delim,
        io,
        anyalloc,
    );

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
    var tmp = std.ArrayList([]const u8).empty;
    defer tmp.deinit(anyalloc);

    tmp = try input.clone(anyalloc);
    input.clearRetainingCapacity();

    for (tmp.items, 0..) |_, i| {
        const val = tmp.items[tmp.items.len - 1 - i];
        try input.append(anyalloc, val);
    }
    return;
}

test "reverse_arr_list" {
    const anyalloc = std.testing.allocator;

    var list = std.ArrayList([]const u8).empty;
    defer list.deinit(anyalloc);

    try list.append(anyalloc, "hello");
    try list.append(anyalloc, "world");

    try reverse_arr_list(anyalloc, &list);

    try std.testing.expectEqualStrings("world", list.items[0]);
    try std.testing.expectEqualStrings("hello", list.items[1]);
}

test "read_hist and test parse" {
    const io: std.Io = std.testing.io;

    const anyalloc = std.testing.allocator;

    const tmp_dir = try std.Io.Dir.openDirAbsolute(io, "/tmp", .{});
    defer tmp_dir.close(io);

    const tmp_filename = try tmp_dir.createFile(io, "test_parse_hist", .{});
    defer tmp_filename.close(io);

    const input_lines = [_][]const u8{
        ": 1752270230:0;img Screenshot\\ from\\ 2025-07-11\\ 15-35-32.png",
        ": 1752270233:0;gcc -o pi_approx2 main2.c -O3 -lpthread",
        ": 1752246391:0;zig build docs\\",
        "python3 -m http.server -d zig-out/docs\\",
        "random broken\\",
        "command here\\",
        "yet another cmd\\",
        "yet another cmd 2",
    };

    var file_writer = tmp_filename.writer(io, &.{});
    const writer = &file_writer.interface;

    for (input_lines) |line| {
        _ = try writer.write(line);
        _ = try writer.writeByte('\n');
    }
    var arr_l = std.ArrayList([]const u8).empty;
    defer arr_l.deinit(anyalloc);
    defer {
        for (arr_l.items) |this_item| {
            anyalloc.free(this_item);
        }
    }

    const to_read_cnt = 42;
    _ = try read_hist(io, anyalloc, &arr_l, .{
        .name = "test_parse_hist",
        .directory = "/tmp/",
        .delim = '\n',
        .entry_max_bytes = 256,
        .number_of_entries = to_read_cnt,
    });

    inline for (
        &.{
            ": 1752246391:0;zig build docs && python3 -m http.server -d zig-out/docs && random broken && command here && yet another cmd && yet another cmd 2",
            ": 1752270233:0;gcc -o pi_approx2 main2.c -O3 -lpthread",
            ": 1752270230:0;img Screenshot\\ from\\ 2025-07-11\\ 15-35-32.png",
        },
        arr_l.items,
    ) |val1, val2| {
        try std.testing.expectEqualStrings(val1, val2);
    }
}
