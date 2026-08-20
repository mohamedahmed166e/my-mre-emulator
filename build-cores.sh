#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$HERE/dist"
export TARGET="${TARGET:-}"

CORES_DEFAULT=(mre)
CORES=("${@:-}"); [ -z "${CORES[*]}" ] && CORES=("${CORES_DEFAULT[@]}")

command -v zig >/dev/null || { echo "ERROR: zig not on PATH"; exit 1; }

mkdir -p "$DIST"
declare -a OK_CORES FAIL_CORES

build_core() {
  local name="$1"
  echo ""
  echo "=== [$name] build WebAssembly core ==="
  
  if [ "$TARGET" = "wasm32-emscripten" ]; then
    # Compile directly using Emscripten for web deployment
    if [ -f "$HERE/$name-core/src/main.c" ]; then
      emcc "$HERE/$name-core/src/main.c" -O3 \
        -s WASM=1 \
        -s FORCE_FILESYSTEM=1 \
        -s EXPORTED_RUNTIME_METHODS='["FS","callMain"]' \
        -o "$DIST/${name}_core.js" || { echo "[$name] emcc build FAILED"; FAIL_CORES+=("$name"); return; }
    else
      # Fallback zig build target for emscripten if configured in build.zig
      cd "$HERE/$name-core" && zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall
      if [ -f "zig-out/bin/${name}.js" ]; then
        cp "zig-out/bin/${name}.js" "$DIST/${name}_core.js"
        cp "zig-out/bin/${name}.wasm" "$DIST/${name}_core.wasm"
      fi
    fi
  else
    # Native libretro build logic
    local dir="$HERE/$name-core"
    ( cd "$dir" && zig build libretro -Doptimize=ReleaseSmall ) || { FAIL_CORES+=("$name"); return; }
    cp "$dir/zig-out/libretro/${name}_libretro.so" "$DIST/"
  fi

  OK_CORES+=("$name")
}

for c in "${CORES[@]}"; do build_core "$c"; done
ls -la "$DIST"
