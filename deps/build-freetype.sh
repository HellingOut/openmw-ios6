#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/freetype-VER-2-11-1"
cmake -S . -B build-ios "${ios_cmake_common[@]}" \
  -DBUILD_SHARED_LIBS=OFF \
  -DFT_DISABLE_BZIP2=TRUE -DFT_DISABLE_HARFBUZZ=TRUE -DFT_DISABLE_BROTLI=TRUE \
  -DFT_DISABLE_PNG=FALSE \
  -DZLIB_INCLUDE_DIR="$DEPS_INCLUDE" -DZLIB_LIBRARY="$DEPS_LIB/libz.a" \
  -DPNG_PNG_INCLUDE_DIR="$DEPS_INCLUDE" -DPNG_LIBRARY="$DEPS_LIB/libpng16.a"
cmake --build build-ios -j"$(nproc)"
cmake --install build-ios
