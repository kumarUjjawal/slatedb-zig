const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream_dir = b.option(
        []const u8,
        "upstream_dir",
        "Path to a SlateDB checkout used for builds and local tests",
    ) orelse "../slatedb";
    const lib_dir_override = b.option(
        []const u8,
        "slatedb_lib_dir",
        "Path to the directory that contains libslatedb_uniffi",
    );

    const default_lib_dir = switch (optimize) {
        .Debug => b.fmt("{s}/target/debug", .{upstream_dir}),
        .ReleaseSafe, .ReleaseFast, .ReleaseSmall => b.fmt("{s}/target/release", .{upstream_dir}),
    };
    const lib_dir = lazyPathFromString(b, lib_dir_override orelse default_lib_dir);

    const slatedb_mod = b.addModule("slatedb", .{
        .root_source_file = b.path("src/slatedb.zig"),
        .target = target,
        .optimize = optimize,
    });
    configureModule(b, slatedb_mod, lib_dir);

    const tests_root = b.createModule(.{
        .root_source_file = b.path("tests/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "slatedb", .module = slatedb_mod },
        },
    });
    configureModule(b, tests_root, lib_dir);

    const example_root = b.createModule(.{
        .root_source_file = b.path("examples/smoke.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "slatedb", .module = slatedb_mod },
        },
    });
    configureModule(b, example_root, lib_dir);

    const unit_tests = b.addTest(.{
        .root_module = tests_root,
    });
    const smoke_example = b.addExecutable(.{
        .name = "slatedb-smoke",
        .root_module = example_root,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_smoke_example = b.addRunArtifact(smoke_example);
    const lib_dir_env = lib_dir_override orelse default_lib_dir;
    run_smoke_example.setEnvironmentVariable("DYLD_LIBRARY_PATH", lib_dir_env);
    run_smoke_example.setEnvironmentVariable("LD_LIBRARY_PATH", lib_dir_env);
    const test_step = b.step("test", "Run Zig binding tests");
    test_step.dependOn(&run_unit_tests.step);
    const example_step = b.step("example", "Run the checked-in smoke example");
    example_step.dependOn(&run_smoke_example.step);
}

fn configureModule(b: *std.Build, module: *std.Build.Module, lib_dir: std.Build.LazyPath) void {
    module.link_libc = true;
    module.addIncludePath(b.path("include"));
    module.addLibraryPath(lib_dir);
    module.addRPath(lib_dir);
    module.linkSystemLibrary("slatedb_uniffi", .{
        .preferred_link_mode = .dynamic,
        .use_pkg_config = .no,
    });
}

fn lazyPathFromString(b: *std.Build, value: []const u8) std.Build.LazyPath {
    if (std.fs.path.isAbsolute(value)) {
        return .{ .cwd_relative = value };
    }
    return b.path(value);
}
