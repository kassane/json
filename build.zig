const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Option
    const tests = b.option(bool, "Tests", "Build tests [default: false]") orelse false;

    const lib = b.addStaticLibrary(.{
        .name = "json",
        .target = target,
        .optimize = optimize,
    });
    lib.installHeadersDirectory("single_include", "");

    if (tests) {
        if (target.isDarwin()) buildTest(b, .{
            .lib = lib,
            .path = "tests/src/fuzzer-parse_json.cpp",
        });
        buildTest(b, .{
            .lib = lib,
            .path = "tests/src/fuzzer-parse_bson.cpp",
        });
        buildTest(b, .{
            .lib = lib,
            .path = "tests/src/fuzzer-parse_ubjson.cpp",
        });
        buildTest(b, .{
            .lib = lib,
            .path = "tests/src/fuzzer-parse_bjdata.cpp",
        });
        buildTest(b, .{
            .lib = lib,
            .path = "tests/src/fuzzer-parse_cbor.cpp",
        });
    }
}

fn buildTest(b: *std.Build, info: BuildInfo) void {
    const test_exe = b.addExecutable(.{
        .name = info.filename(),
        .optimize = info.lib.optimize,
        .target = info.lib.target,
    });
    test_exe.addIncludePath(.{ .path = "include" });
    test_exe.addIncludePath(.{ .path = "tests/src/" });
    test_exe.addIncludePath(.{ .path = "tests/thirdparty/doctest" });
    test_exe.addIncludePath(.{ .path = "tests/thirdparty/Fuzzer" });
    test_exe.addCSourceFile(.{ .file = .{ .path = info.path }, .flags = cxxFlags });
    test_exe.defineCMacro("DOCTEST_CONFIG_SUPER_FAST_ASSERTS", null);
    test_exe.addCSourceFile(.{ .file = .{ .path = "tests/thirdparty/Fuzzer/standalone/StandaloneFuzzTargetMain.c" }, .flags = cxxFlags });
    if (test_exe.target.getAbi() != .msvc)
        test_exe.linkLibCpp()
    else
        test_exe.linkLibC();
    b.installArtifact(test_exe);

    const run_cmd = b.addRunArtifact(test_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(
        b.fmt("{s}", .{info.filename()}),
        b.fmt("Run the {s} test", .{info.filename()}),
    );
    run_step.dependOn(&run_cmd.step);
}

const cxxFlags: []const []const u8 = &.{
    "-Wall",
    "-Wextra",
    "-Wpedantic",
};

const BuildInfo = struct {
    lib: *std.Build.Step.Compile,
    path: []const u8,

    fn filename(self: BuildInfo) []const u8 {
        var split = std.mem.splitSequence(u8, std.fs.path.basename(self.path), ".");
        return split.first();
    }
};
