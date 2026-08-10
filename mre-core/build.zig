// --- WASM libretro core ----------------------------------------------------
    // `zig build wasm` -> zig-out/lib/handyplay.wasm
    {
        const wasm_target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        });

        const wasm_mod = b.createModule(.{
            .root_source_file = b.path("frontends/libretro/core.zig"),
            .target = wasm_target,
            .optimize = optimize,
        });

        const wasm_lib = b.addExecutable(.{
            .name = "handyplay",
            .root_module = wasm_mod,
        });

        wasm_lib.entry = .disabled;
        wasm_lib.rdynamic = true;

        const wasm_inst = b.addInstallArtifact(wasm_lib, .{
            .dest_dir = .{ .override = .bin },
        });

        b.step("wasm", "Build the WebAssembly libretro core").dependOn(&wasm_inst.step);
    }
