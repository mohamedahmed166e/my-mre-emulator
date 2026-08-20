#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$HERE/dist"

mkdir -p "$DIST"

echo "=== Building MRE Core for WebAssembly ==="

# Navigate to core directory
if [ -d "$HERE/mre-core" ]; then
    cd "$HERE/mre-core"
else
    echo "ERROR: mre-core directory not found!"
    exit 1
fi

# Build Wasm using Zig
if [ -f "build.zig" ]; then
    zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall || zig build -Doptimize=ReleaseSmall || true
fi

# Search and copy all generated .js and .wasm files directly into dist/
find "$HERE" -type f \( -name "*.wasm" -o -name "*.js" \) ! -path "*/dist/*" -exec cp -v {} "$DIST/" \;

echo "=== DIST DIRECTORY CONTENTS ==="
ls -la "$DIST"
