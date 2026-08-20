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

# Find all C source files
C_FILES=$(find "$CORE_DIR" -type f -name "*.c")

# Scan the entire workspace for directories containing header files (.h / .hpp)
INCLUDE_FLAGS=""
for dir in $(find "$HERE" -type f \( -name "*.h" -o -name "*.hpp" \) -exec dirname {} \; | sort -u); do
    INCLUDE_FLAGS="$INCLUDE_FLAGS -I$dir"
done

echo "Configured Include Paths:"
echo "$INCLUDE_FLAGS"

# Fallback explicit inclusions if headers are deeply nested
INCLUDE_FLAGS="$INCLUDE_FLAGS -I$CORE_DIR -I$CORE_DIR/core -I$CORE_DIR/src -I$CORE_DIR/include"

# Compile via Emscripten
emcc $C_FILES \
  $INCLUDE_FLAGS \
  -O2 \
  -s WASM=1 \
  -s FORCE_FILESYSTEM=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s EXPORTED_RUNTIME_METHODS='["FS","callMain","cwrap","ccall"]' \
  -s EXPORTED_FUNCTIONS='["_main"]' \
  -o "$DIST/mre_core.js"

echo "=== BUILD SUCCESSFUL ==="
ls -la "$DIST"
