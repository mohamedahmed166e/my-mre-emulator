#!/usr/bin/env bash
# Build the Handyplay emulator cores as native libretro cores
# (<core>_libretro.{so,dylib}) for RetroArch and any other libretro frontend.
#
#   ./build-cores.sh [core ...]              # default: all (exen mre mrp), native host
#   TARGET=x86_64-windows-gnu ./build-cores.sh exen   # cross-compile (-> .dll)
#
# Each core is built via `zig build libretro` (defined in its build.zig),
# then the resulting shared library is collected into dist/cores/.
#
# Set TARGET to a Zig target triple to cross-compile to any RetroArch platform
# (Windows .dll, Linux/Android/handheld .so, macOS/iOS .dylib). exen has no
# native deps and cross-compiles freely; mre/mrp link Unicorn and need a
# libunicorn built for that target (in ../vendor/unicorn/build).
#
# BIOS / fonts are NOT staged here — they are user-supplied and located by MD5
# at runtime from the libretro system directory (see README "BIOS / fonts").
#
# Prereqs: zig (0.15+) on PATH.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$HERE/dist/cores"
export TARGET="${TARGET:-}"

CORES_DEFAULT=(exen mre mrp)
CORES=("${@:-}"); [ -z "${CORES[*]}" ] && CORES=("${CORES_DEFAULT[@]}")

# name -> core-dir-relative-to-HERE
dir_for() {
  case "$1" in
    exen) echo "exen-core" ;;
    mre)  echo "mre-core" ;;
    mrp)  echo "mrp-core" ;;
    *)    echo "" ;;
  esac
}

command -v zig >/dev/null || { echo "ERROR: zig not on PATH"; exit 1; }
case "${TARGET:-$(uname -s)}" in
  *windows*|MINGW*|MSYS*|CYGWIN*) EXT=dll ;;
  *macos*|*darwin*|Darwin|*ios*)  EXT=dylib ;;
  *)                              EXT=so ;;
esac

mkdir -p "$DIST"
declare -a OK_CORES FAIL_CORES

build_core() {
  local name="$1" rel dir
  rel="$(dir_for "$name")"
  [ -z "$rel" ] && { echo "[$name] unknown core — skipping"; FAIL_CORES+=("$name"); return; }
  dir="$HERE/$rel"

  echo ""
  echo "=== [$name] build native libretro core ==="
  if [ ! -f "$dir/build.zig" ]; then
    echo "[$name] missing $dir/build.zig"; FAIL_CORES+=("$name"); return
  fi
  ( cd "$dir" && zig build libretro -Doptimize=ReleaseSmall ${TARGET:+-Dtarget="$TARGET"} ) \
    || { echo "[$name] build FAILED"; FAIL_CORES+=("$name"); return; }

  local lib="$dir/zig-out/libretro/${name}_libretro.$EXT"
  if [ -f "$lib" ]; then
    cp "$lib" "$DIST/"
    echo "[$name] OK -> dist/cores/${name}_libretro.$EXT"
    OK_CORES+=("$name")
  else
    echo "[$name] expected $lib not found"; FAIL_CORES+=("$name")
  fi
}

for c in "${CORES[@]}"; do build_core "$c"; done

echo ""
echo "================ summary ================"
echo "built:  ${OK_CORES[*]:-(none)}"
echo "failed: ${FAIL_CORES[*]:-(none)}"
ls -la "$DIST" 2>/dev/null
[ ${#FAIL_CORES[@]} -eq 0 ]
