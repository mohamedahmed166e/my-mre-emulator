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

# Automatically discover and add all directories containing header files (.h)
INCLUDE_FLAGS=""
for dir in $(find "$CORE_DIR" -type f -name "*.h" -exec dirname {} \; | sort -u); do
    INCLUDE_FLAGS="$INCLUDE_FLAGS -I$dir"
done

echo "Include paths configured:"
echo "$INCLUDE_FLAGS"

# Compile with dynamic include paths, Virtual File System support, and exported methods
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
