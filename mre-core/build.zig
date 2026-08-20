const std = @import("std");

// Path to Unicorn relative to mre-core
const unicorn_root = "vendor/unicorn";

/// Attach Unicorn include/lib/link to a module so every consumer inherits it.
fn addUnicorn(b: *std.Build, mod: *std.Build.Module) void {
    mod.link_libc = true;
    mod.addIncludePath(b.path(unicorn_root ++ "/include"));
    mod.addLibraryPath(b.path(unicorn_root ++ "/build"));
    mod.addLibraryPath(b.path(unicorn_root ++ "/build/Release"));
    mod.linkSystemLibrary("unicorn", .{});
}

/// Attach the vendored TinySoundFont & minimp3 implementation.
fn addTsf(b: *std.Build, mod: *std.Build.Module) void {
    mod.addIncludePath(b.path("vendor/TinySoundFont"));
    mod.addCSourceFile(.{ .file = b.path("core/tsf_impl.c"), .flags = &.{"-O2"} });
    mod.addIncludePath(b.path("vendor/minimp3"));
    mod.addCSourceFile(.{ .file = b.path("core/mp3_impl.c"), .flags = &.{"-O2"} });
}

/// Attach SDL3 dynamically depending on OS environment.
fn addSdl(b: *std.Build, mod: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    mod.link_libc = true;

    // Handle macOS Homebrew vs General / Windows vendor paths
    if (target.result.os.tag == .macos) {
        mod.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
        mod.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    } else {
        mod.addIncludePath(b.path("vendor/sdl3/include"));
        mod.addLibraryPath(b.path("vendor/sdl3/lib"));
    }

    mod.linkSystemLibrary("SDL3", .{});
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- core module ---------------------------------------------------------
    const core = b.addModule("core", .{
        .root_source_file = b.path("core/mreemu.zig"),
        .target = target,
        .optimize = optimize,
    });
    addUnicorn(b, core);
    addTsf(b, core);

    const Tool = struct {
        fn add(bb: *std.Build, c: *std.Build.Module, t: std.Build.ResolvedTarget, o: std.builtin.OptimizeMode, name: []const u8, src: []const u8, step_name: []const u8, desc: []const u8) void {
            const mod = bb.createModule(.{ .root_source_file = bb.path(src), .target = t, .optimize = o });
            mod.addImport("core", c);
            const exe = bb.addExecutable(.{ .name = name, .root_module = mod });
            bb.installArtifact(exe);
            const run = bb.addRunArtifact(exe);
            if (bb.args) |args| run.addArgs(args);
            bb.step(step_name, desc).dependOn(&run.step);
        }
    };

    // --- Tools ---------------------------------------------------------------
    const extract = b.addExecutable(.{
        .name = "vxp-extract",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vxp_extract.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(extract);

    const smoke_mod = b.createModule(.{ .root_source_file = b.path("tools/uc_smoke.zig"), .target = target, .optimize = optimize });
    addUnicorn(b, smoke_mod);
    const uc_smoke = b.addExecutable(.{ .name = "uc-smoke", .root_module = smoke_mod });
    b.installArtifact(uc_smoke);

    Tool.add(b, core, target, optimize, "loadtest", "tools/loadtest.zig", "loadtest", "Load a .vxp and report its layout");
    Tool.add(b, core, target, optimize, "vxp2elf", "tools/vxp2elf.zig", "vxp2elf", "Load a .vxp and emit a relocated ELF");
    Tool.add(b, core, target, optimize, "run", "tools/run.zig", "run", "Load and run a .vxp");
    Tool.add(b, core, target, optimize, "natives-from-c", "tools/natives_from_c.zig", "natives-from-c", "Classify natives in C");

    // --- SDL Frontend --------------------------------------------------------
    const sdl_mod = b.createModule(.{ .root_source_file = b.path("frontends/sdl/main.zig"), .target = target, .optimize = optimize });
    sdl_mod.addImport("core", core);
    addSdl(b, sdl_mod, target);
    const sdl_exe = b.addExecutable(.{ .name = "mre-sdl", .root_module = sdl_mod });
    b.installArtifact(sdl_exe);
}
