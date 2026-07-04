const std = @import("std");

/// Executable name.
const exe_name = "zistory";

/// Executable name.
const exe_version = "0.1.0";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zistory", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const data_s_mod = b.addModule("data_structs", .{
        .root_source_file = b.path("src/data_structs.zig"),
        .target = target,
    });
    const hist_reader_mod = b.addModule("hist_reader", .{
        .root_source_file = b.path("src/hist_reader.zig"),
        .target = target,
    });

    // c translation
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("data_structs", data_s_mod);
    mod.addImport("hist_reader", hist_reader_mod);
    data_s_mod.addImport("hist_reader", hist_reader_mod);
    data_s_mod.addImport("c", translate_c.createModule());

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const rl_bar_chart_dep = b.dependency("raylib_bar_chart", .{
        .target = target,
        .optimize = optimize,
    });
    const rl_lists_dep = b.dependency("raylib_lists", .{
        .target = target,
        .optimize = optimize,
    });
    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
    const rl_bar_chart = rl_bar_chart_dep.module("raylib_bar_chart"); // bar graph
    const rl_lists = rl_lists_dep.module("raylib_lists"); // lists

    const exe = b.addExecutable(.{
        .name = "zistory_bin",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zistory", .module = mod },
                .{ .name = "data_structs", .module = data_s_mod },
                .{ .name = "hist_reader", .module = hist_reader_mod },
            },
        }),
    });

    // options
    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options", exe_options);
    exe_options.addOption([]const u8, "exe_name", exe_name);
    exe_options.addOption([]const u8, "version", exe_version);

    // linking
    exe.root_module.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);
    exe.root_module.addImport("rl_bar_graph", rl_bar_chart);
    exe.root_module.addImport("rl_lists", rl_lists);
    exe.root_module.addImport("clap", clap.module("clap"));

    mod.linkLibrary(raylib_artifact);
    mod.addImport("raylib", raylib);
    mod.addImport("raygui", raylib);
    mod.addImport("rl_bar_graph", rl_bar_chart);
    mod.addImport("rl_lists", rl_lists);

    data_s_mod.linkLibrary(raylib_artifact);
    data_s_mod.addImport("raylib", raylib);
    data_s_mod.addImport("raygui", raylib);
    data_s_mod.addImport("rl_bar_graph", rl_bar_chart);
    data_s_mod.addImport("rl_lists", rl_lists);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // tests
    const mod_tests = b.addTest(.{
        .name = "mod-tests",
        .root_module = mod,
    });
    const data_s_mod_tests = b.addTest(.{
        .name = "data_structs-tests",
        .root_module = data_s_mod,
    });
    const hist_reader_mod_tests = b.addTest(.{
        .name = "hist_reader-tests",
        .root_module = hist_reader_mod,
    });
    const exe_tests = b.addTest(.{
        .name = "exe-tests",
        .root_module = exe.root_module,
    });

    // code coverage
    const xgd_home = b.graph.environ_map.get("HOME") orelse "";
    const exclude_pat = b.fmt("--exclude-path={s}/.cache/zig", .{xgd_home});

    const code_cov = b.option(bool, "test_coverage", "Gen the code coverage") orelse false;
    const arg: []const ?[]const u8 = &[_]?[]const u8{
        "kcov",
        "--clean",
        exclude_pat,
        "--include-pattern=src/",
        "kcov-out",
        null,
    };

    if (code_cov) {
        mod_tests.setExecCmd(arg);
        data_s_mod_tests.setExecCmd(arg);
        hist_reader_mod_tests.setExecCmd(arg);
        exe_tests.setExecCmd(arg);
    }

    const run_mod_tests = b.addRunArtifact(mod_tests);
    const run_data_s_mod_tests = b.addRunArtifact(data_s_mod_tests);
    const run_hist_reader_mod_tests = b.addRunArtifact(hist_reader_mod_tests);
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_data_s_mod_tests.step);
    test_step.dependOn(&run_hist_reader_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // docs
    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);
}
