const std = @import("std");
const zgui = @import("zgui");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const zpool = @import("zpool");
const zstbi = @import("zstbi");
const zmath = @import("zmath");

const content_dir = "content/";

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "raytrace",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const zgui_pkg = zgui.package(b, target, optimize, .{
        .options = .{ .backend = .glfw_wgpu },
    });

    // const zgui_pkg = zgui.package(b, target, optimize, .{});
    // const zmath_pkg = zmath.package(b, target, optimize, .{});
    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    // const zgpu_pkg = zgpu.package(b, target, optimize, .{});
    const zpool_pkg = zpool.package(b, target, optimize, .{});
    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const zgpu_pkg = zgpu.package(b, target, optimize, .{
        .deps = .{ .zpool = zpool_pkg, .zglfw = zglfw_pkg },
    });

    zgui_pkg.link(exe);
    zgpu_pkg.link(exe);
    zglfw_pkg.link(exe);
    zstbi_pkg.link(exe);
    // zmath_pkg.link(exe);
    // zpool_pkg.link(exe);

    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options", exe_options);
    exe_options.addOption([]const u8, "content_dir", content_dir);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = .{ .path = thisDir() ++ "/" ++ content_dir },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    exe.step.dependOn(&install_content_step.step);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    zgui_pkg.link(exe_unit_tests);
    zgpu_pkg.link(exe_unit_tests);
    zglfw_pkg.link(exe_unit_tests);
    zstbi_pkg.link(exe_unit_tests);

    exe_unit_tests.step.dependOn(&install_content_step.step);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
