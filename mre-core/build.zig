const std = @import("std");

// Vendored Unicorn (CPU emulator), shared by the mre/mrp cores in ../vendor/unicorn.
const unicorn_root = "../vendor/unicorn";

/// Attach Unicorn include/lib/link to a module so every consumer inherits it.
fn addUnicorn(mod: *std.Build.Module) void {
    mod.link_libc = true;
    mod.addIncludePath(.{ .cwd_relative = unicorn_root ++ "/include" });
    mod.addLibraryPath(.{ .cwd_relative = unicorn_root ++ "/build" });
    mod.linkSystemLibrary("unicorn", .{});
}

/// Attach the vendored TinySoundFont
fn addTsf(b: *std.Build, mod: *std.Build.Module) void {
    mod.addIncludePath(.{ .cwd_relative = "../vendor/TinySoundFont" });
    mod.addCSourceFile(.{ .file = b.path("core/tsf_impl.c"), .flags = &.{"-O2"} });
    mod.addIncludePath(.{ .cwd_relative = "../vendor/minimp3" });
    mod.addCSourceFile(.{ .file = b.path("core/mp3_impl.c"), .flags = &.{"-O2"} });
}

fn addSdl(mod: *std.Build.Module) void {
    mod.link_libc = true;
    mod.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    mod.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    mod.linkSystemLibrary("SDL3", .{});
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- core module (frontend-agnostic VM + loader + memory) ----------------
    const core = b.addModule("core", .{
        .root_source_file = b.path("core/mreemu.zig"),
        .target = target,
        .optimize = optimize,
    });
    addUnicorn(core);
    addTsf(b, core);

    // helper to make a tool exe that imports core
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

    // --- vxp -> elf extractor -------------------
    const extract = b.addExecutable(.{
        .name = "vxp-extract",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vxp_extract.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(extract);
    const run_extract = b.addRunArtifact(extract);
    if (b.args) |args| run_extract.addArgs(args);
    b.step("extract", "Extract a .vxp -> .elf").dependOn(&run_extract.step);

    // --- Phase 0 smoke ------------------
    const smoke_mod = b.createModule(.{ .root_source_file = b.path("tools/uc_smoke.zig"), .target = target, .optimize = optimize });
    addUnicorn(smoke_mod);
    const uc_smoke = b.addExecutable(.{ .name = "uc-smoke", .root_module = smoke_mod });
    b.installArtifact(uc_smoke);
    b.step("smoke", "Run the Unicorn smoke test").dependOn(&b.addRunArtifact(uc_smoke).step);

    // --- tools / frontends ----------------------------------------------------
    Tool.add(b, core, target, optimize, "loadtest", "tools/loadtest.zig", "loadtest", "Load a .vxp and report its layout");
    Tool.add(b, core, target, optimize, "vxp2elf", "tools/vxp2elf.zig", "vxp2elf", "Load a .vxp and emit a relocated ELF for decompilers");
    Tool.add(b, core, target, optimize, "run", "tools/run.zig", "run", "Load and run a .vxp (headless, logs bridge calls)");
    Tool.add(b, core, target, optimize, "natives-from-c", "tools/natives_from_c.zig", "natives-from-c", "Classify natives in a decompiled .c (implemented/stubbed/missing, verified/unverified)");

    // SDL3 live window
    const sdl_mod = b.createModule(.{ .root_source_file = b.path("frontends/libretro/core.zig"), .target = target, .optimize = optimize });
    sdl_mod.addImport("core", core);
    addSdl(sdl_mod);
    const sdl_exe = b.addExecutable(.{ .name = "mre-sdl", .root_module = sdl_mod });
    b.installArtifact(sdl_exe);
    const run_sdl = b.addRunArtifact(sdl_exe);
    if (b.args) |args| run_sdl.addArgs(args);
    b.step("run-sdl", "Run a .vxp in an SDL3 window").dependOn(&run_sdl.step);

    // --- unit tests -----------------------------------------------------------
    const test_step = b.step("test", "Run core unit tests");
    for ([_][]const u8{ "core/memory.zig", "core/loader/tags.zig", "core/codecs/png.zig", "core/codecs/gif.zig", "core/codecs/wav.zig" }) |root| {
        const tmod = b.createModule(.{ .root_source_file = b.path(root), .target = target, .optimize = optimize });
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = tmod })).step);
    }
    {
        const tmod = b.createModule(.{ .root_source_file = b.path("core/audio.zig"), .target = target, .optimize = optimize });
        tmod.link_libc = true;
        addTsf(b, tmod);
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = tmod })).step);
    }

    // --- native libretro core --------------------------------------------------
    {
        const lr_mod = b.createModule(.{
            .root_source_file = b.path("frontends/libretro/core.zig"),
            .target = target,
            .optimize = optimize,
        });
        lr_mod.addImport("core", core);
        addUnicorn(lr_mod);
        const lr = b.addLibrary(.{ .name = "mre_libretro", .root_module = lr_mod, .linkage = .dynamic });
        const ext = switch (target.result.os.tag) {
            .windows => "dll",
            .macos, .ios, .tvos, .watchos => "dylib",
            else => "so",
        };
        const inst = b.addInstallArtifact(lr, .{
            .dest_dir = .{ .override = .{ .custom = "libretro" } },
            .dest_sub_path = b.fmt("mre_libretro.{s}", .{ext}),
        });
        b.step("libretro", "Build the native libretro core (shared library)").dependOn(&inst.step);
    }

    // --- WASM libretro core ----------------------------------------------------
    {
        const wasm_target = std.zig.CrossTarget{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        };

        const wasm_mod = b.createModule(.{
            .root_source_file = b.path("frontends/libretro/core.zig"),
            .target = wasm_target,
            .optimize = optimize,
        });

        const wasm_lib = b.addSharedLibrary(.{
            .name = "handyplay",
            .root_module = wasm_mod,
        });

        wasm_lib.rdynamic = true;

        const wasm_inst = b.addInstallArtifact(wasm_lib, .{
            .dest_dir = .{ .override = .bin },
        });

        b.step("wasm", "Build the WebAssembly libretro core").dependOn(&wasm_inst.step);
    }
}
