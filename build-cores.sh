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
  local dir="$HERE/${name}-core"
  echo ""
  echo "=== [$name] building core ==="

  if [ "$TARGET" = "wasm32-emscripten" ]; then
    # Direct Emscripten compilation if source files exist directly
    if [ -f "$dir/src/main.c" ] || [ -f "$dir/main.c" ]; then
      local src_file="$dir/src/main.c"
      [ ! -f "$src_file" ] && src_file="$dir/main.c"

      emcc "$src_file" -O3 \
        -s WASM=1 \
        -s FORCE_FILESYSTEM=1 \
        -s EXPORTED_RUNTIME_METHODS='["FS","callMain"]' \
        -o "$DIST/${name}_core.js" || { echo "[$name] emcc build FAILED"; FAIL_CORES+=("$name"); return; }
    else
      # Zig build fallback for Wasm target
      ( cd "$dir" && zig build -Doptimize=ReleaseSmall ${TARGET:+-Dtarget="$TARGET"} ) || true
    fi

    # Copy any compiled JS/WASM binaries found in the core directory
    find "$dir" -type f \( -name "*.wasm" -o -name "*.js" \) -exec cp -v {} "$DIST/" \;
  else
    # Native libretro build
    ( cd "$dir" && zig build libretro -Doptimize=ReleaseSmall ) || { FAIL_CORES+=("$name"); return; }
    find "$dir" -type f \( -name "*.so" -o -name "*.dll" -o -name "*.dylib" \) -exec cp -v {} "$DIST/" \;
  fi

  OK_CORES+=("$name")
}

for c in "${CORES[@]}"; do build_core "$c"; done

echo ""
echo "=== BUILD COMPLETE ==="
ls -la "$DIST"
