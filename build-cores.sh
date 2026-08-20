#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$HERE/dist"

rm -rf "$DIST"
mkdir -p "$DIST"

echo "=== Compiling MRE Core for WebAssembly ==="

CORE_DIR="$HERE/mre-core"

if [ ! -d "$CORE_DIR" ]; then
    echo "ERROR: mre-core directory does not exist!"
    exit 1
fi

C_FILES=$(find "$CORE_DIR" -type f -name "*.c")

INCLUDE_FLAGS=""
while IFS= read -r dir; do
    if [ -n "$dir" ]; then
        INCLUDE_FLAGS="$INCLUDE_FLAGS -I$dir"
    fi
done < <(find "$HERE" -type f \( -name "*.h" -o -name "*.hpp" \) -exec dirname {} \; | sort -u)

# Compile while forcing symbol visibility across all C sources
emcc $C_FILES \
  $INCLUDE_FLAGS \
  -O2 \
  -s WASM=1 \
  -s FORCE_FILESYSTEM=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s INVOKE_RUN=0 \
  -s ERROR_ON_UNDEFINED_SYMBOLS=0 \
  -s WARN_ON_UNDEFINED_SYMBOLS=0 \
  -s EXPORT_ALL=1 \
  -s EXPORTED_RUNTIME_METHODS='["FS","cwrap","ccall","getValue","setValue","UTF8ToString"]' \
  -o "$DIST/mre_core.js"

echo "=== BUILD COMPLETE ==="
ls -la "$DIST"
