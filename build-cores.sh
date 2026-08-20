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

# Find all C files inside mre-core
C_FILES=$(find "$CORE_DIR" -type f -name "*.c")

if [ -z "$C_FILES" ]; then
    echo "ERROR: No .c files found in $CORE_DIR"
    exit 1
fi

echo "Found C sources:"
echo "$C_FILES"

# Compile directly using Emscripten to output mre_core.js and mre_core.wasm
emcc $C_FILES -O2 \
  -s WASM=1 \
  -s FORCE_FILESYSTEM=1 \
  -s EXPORTED_RUNTIME_METHODS='["FS","callMain"]' \
  -s ALLOW_MEMORY_GROWTH=1 \
  -o "$DIST/mre_core.js"

echo "=== BUILD OUTPUT CONTENTS ==="
ls -la "$DIST"
