const std = @import("std");

// Vendored Unicorn (CPU emulator), shared by the mre/mrp cores in ../vendor/unicorn.
const unicorn_root = "../vendor/unicorn";

/// Attach Unicorn include/lib/link to a module so every consumer inherits it.
fn addUnicorn(mod: *std.Build.Module) void {
    mod.link_libc = true;
    mod.addIncludePath(.{ .path = unicorn_root ++ "/include" });
    mod.addLibraryPath(.{ .path = unicorn_root ++ "/build" });
    mod.linkSystemLibrary("unicorn", .{});
}

/// Attach the vendored TinySoundFont
fn addTsf(b: *std.Build, mod: *std.Build.Module) void {
    _ = b;
    mod.addIncludePath(.{ .path = "../vendor/TinySoundFont" });
    mod.addCSourceFile(.{ .file = .{ .path = "core/tsf_impl.c" }, .flags = &.{"-O2"} });
    mod.addIncludePath(.{ .path = "../vendor/minimp3" });
    mod.addCSourceFile(.{ .file = .{ .path = "core/mp3_impl.c" }, .flags = &.{"-O2"} });
}

fn addSdl(mod: *std.Build.Module) void {
    mod.link_libc = true;
    mod.addIncludePath(.{ .path = "/opt/homebrew/include" });
    mod.addLibraryPath(.{ .path = "/opt/homebrew/lib" });
    mod.linkSystemLibrary("SDL3", .{});
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- core module (frontend-agnostic VM + loader + memory) ----------------
    const core = b.addModule("core", .{
        .source_file = .{ .path = "core/mreemu.zig" },
        .dependencies = &.{},
    });
    addUnicorn(core);
    addTsf(b, core);

    // --- vxp -> elf extractor -------------------
    const extract = b.addExecutable(.{
        .name = "vxp-extract",
        .root_source_file = .{ .path = "src/vxp_extract.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(extract);
    const run_extract = b.addRunArtifact(extract);
    if (b.args) |args| run_extract.addArgs(args);
    b.step("extract", "Extract a .vxp -> .elf").dependOn(&run_extract.step);

    // --- Phase 0 smoke ------------------
    const smoke_exe = b.addExecutable(.{
        .name = "uc-smoke",
        .root_source_file = .{ .path = "tools/uc_smoke.zig" },
        .target = target,
        .optimize = optimize,
    });
    addUnicorn(&smoke_exe.root_module);
    b.installArtifact(smoke_exe);
    b.step("smoke", "Run the Unicorn smoke test").dependOn(&b.addRunArtifact(smoke_exe).step);

    // --- tools / frontends ----------------------------------------------------
    const tools = [_]struct { name: []const u8, src: []const u8, step: []const u8, desc: []const u8 }{
        .{ .name = "loadtest", .src = "tools/loadtest.zig", .step = "loadtest", .desc = "Load a .vxp and report layout" },
        .{ .name = "vxp2elf", .src = "tools/vxp2elf.zig", .step = "vxp2elf", .desc = "Emit relocated ELF" },
        .{ .name = "run", .src = "tools/run.zig", .step = "run", .desc = "Load and run a .vxp headless" },
        .{ .name = "natives-from-c", .src = "tools/natives_from_c.zig", .step = "natives-from-c", .desc = "Classify natives" },
    };

    inline for (tools) |t| {
        const exe = b.addExecutable(.{
            .name = t.name,
            .root_source_file = .{ .path = t.src },
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addModule("core", core);
        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| run_cmd.addArgs(args);
        b.step(t.step, t.desc).dependOn(&run_cmd.step);
    }

    // SDL3 live window
    const sdl_exe = b.addExecutable(.{
        .name = "mre-sdl",
        .root_source_file = .{ .path = "frontends/libretro/core.zig" },
        .target = target,
        .optimize = optimize,
    });
    sdl_exe.root_module.addModule("core", core);
    addSdl(&sdl_exe.root_module);
    b.installArtifact(sdl_exe);
    const run_sdl = b.addRunArtifact(sdl_exe);
    if (b.args) |args| run_sdl.addArgs(args);
    b.step("run-sdl", "Run a .vxp in an SDL3 window").dependOn(&run_sdl.step);

    // --- unit tests -----------------------------------------------------------
    const test_step = b.step("test", "Run core unit tests");
    const test_files = [_][]const u8{
        "core/memory.zig",
        "core/loader/tags.zig",
        "core/codecs/png.zig",
        "core/codecs/gif.zig",
        "core/codecs/wav.zig",
    };
    inline for (test_files) |tf| {
        const t = b.addTest(.{
            .root_source_file = .{ .path = tf },
            .target = target,
            .optimize = optimize,
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    const audio_test = b.addTest(.{
        .root_source_file = .{ .path = "core/audio.zig" },
        .target = target,
        .optimize = optimize,
    });
    audio_test.root_module.link_libc = true;
    addTsf(b, &audio_test.root_module);
    test_step.dependOn(&b.addRunArtifact(audio_test).step);

    // --- native libretro core --------------------------------------------------
    {
        const lr = b.addSharedLibrary(.{
            .name = "mre_libretro",
            .root_source_file = .{ .path = "frontends/libretro/core.zig" },
            .target = target,
            .optimize = optimize,
        });
        lr.root_module.addModule("core", core);
        addUnicorn(&lr.root_module);

        const ext = switch (target.getOsTag()) {
            .windows => "dll",
            .macos, .ios, .tvos, .watchos => "dylib",
            else => "so",
        };
        const inst = b.addInstallArtifact(lr, .{
            .dest_dir = .{ .override = .{ .custom = "libretro" } },
            .dest_sub_path = b.fmt("mre_libretro.{s}", .{ext}),
        });
        b.step("libretro", "Build native libretro core").dependOn(&inst.step);
    }

    // --- WASM libretro core ----------------------------------------------------
    {
        const wasm_target = std.zig.CrossTarget{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        };

        const wasm_lib = b.addSharedLibrary(.{
            .name = "handyplay",
            .root_source_file = .{ .path = "frontends/libretro/core.zig" },
            .target = wasm_target,
            .optimize = optimize,
        });

        wasm_lib.rdynamic = true;

        const wasm_inst = b.addInstallArtifact(wasm_lib, .{
            .dest_dir = .{ .override = .bin },
        });

        b.step("wasm", "Build the WebAssembly libretro core").dependOn(&wasm_inst.step);
    }
}
