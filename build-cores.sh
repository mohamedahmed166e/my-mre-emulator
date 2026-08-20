#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$HERE/dist"

mkdir -p "$DIST"

echo "=== Compiling MRE Core for WebAssembly ==="

CORE_DIR="$HERE/mre-core"

if [ ! -d "$CORE_DIR" ]; then
    echo "ERROR: mre-core directory does not exist!"
    exit 1
fi

# Locate all C files inside mre-core
C_FILES=$(find "$CORE_DIR" -type f -name "*.c")

# Discover all header directories
INCLUDE_FLAGS=""
while IFS= read -r dir; do
    if [ -n "$dir" ]; then
        INCLUDE_FLAGS="$INCLUDE_FLAGS -I$dir"
    fi
done < <(find "$HERE" -type f \( -name "*.h" -o -name "*.hpp" \) -exec dirname {} \; | sort -u)

# Compile using Emscripten to output WebAssembly JS and WASM files
emcc $C_FILES \
  $INCLUDE_FLAGS \
  -O2 \
  -s WASM=1 \
  -s FORCE_FILESYSTEM=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s EXPORTED_RUNTIME_METHODS='["FS","callMain","cwrap","ccall"]' \
  -s EXPORTED_FUNCTIONS='["_main"]' \
  -o "$DIST/mre_core.js"

echo "=== Wasm Build Complete ==="
ls -la "$DIST"
