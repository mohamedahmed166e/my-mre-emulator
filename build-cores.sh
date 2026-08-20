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
    local dir="$HERE/${name}-core"
    
    if [ -f "$dir/src/main.c" ]; then
      emcc "$dir/src/main.c" -O3 \
        -s WASM=1 \
        -s FORCE_FILESYSTEM=1 \
        -s EXPORTED_RUNTIME_METHODS='["FS","callMain"]' \
        -o "$DIST/${name}_core.js" || { echo "[$name] emcc build FAILED"; FAIL_CORES+=("$name"); return; }
    else
      ( cd "$dir" && zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall ) || { FAIL_CORES+=("$name"); return; }
      if [ -f "$dir/zig-out/bin/${name}.js" ]; then
        cp "$dir/zig-out/bin/${name}.js" "$DIST/${name}_core.js"
        cp "$dir/zig-out/bin/${name}.wasm" "$DIST/${name}_core.wasm" 2>/dev/null || true
      fi
    fi
  else
    local dir="$HERE/${name}-core"
    ( cd "$dir" && zig build libretro -Doptimize=ReleaseSmall ) || { FAIL_CORES+=("$name"); return; }
    cp "$dir/zig-out/libretro/${name}_libretro.so" "$DIST/" 2>/dev/null || true
  fi

  OK_CORES+=("$name")
}

for c in "${CORES[@]}"; do build_core "$c"; done

echo ""
echo "=== BUILD COMPLETE ==="
ls -la "$DIST"
