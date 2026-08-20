#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$HERE/dist"

# Ensure clean dist directory
rm -rf "$DIST"
mkdir -p "$DIST"

echo "=== Compiling MRE Core for WebAssembly ==="

CORE_DIR="$HERE/mre-core"

if [ ! -d "$CORE_DIR" ]; then
    echo "ERROR: mre-core directory does not exist!"
    exit 1
fi

# Find all C source files inside mre-core
C_FILES=$(find "$CORE_DIR" -type f -name "*.c")

# Discover all header directories dynamically
INCLUDE_FLAGS=""
while IFS= read -r dir; do
    if [ -n "$dir" ]; then
        INCLUDE_FLAGS="$INCLUDE_FLAGS -I$dir"
    fi
done < <(find "$HERE" -type f \( -name "*.h" -o -name "*.hpp" \) -exec dirname {} \; | sort -u)

# Compile to dist/mre_core.js and dist/mre_core.wasm
emcc $C_FILES \
  $INCLUDE_FLAGS \
  -O2 \
  -s WASM=1 \
  -s FORCE_FILESYSTEM=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s ERROR_ON_UNDEFINED_SYMBOLS=0 \
  -s WARN_ON_UNDEFINED_SYMBOLS=0 \
  -s EXPORTED_RUNTIME_METHODS='["FS","cwrap","ccall"]' \
  -o "$DIST/mre_core.js"

echo "=== VERIFYING GENERATED DIST ASSETS ==="
ls -la "$DIST"
