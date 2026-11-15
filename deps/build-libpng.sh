#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/libpng-1.6.37"
cmake -S . -B build-ios "${ios_cmake_common[@]}" \
  -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF -DPNG_ARM_NEON=off \
  -DPNG_EXECUTABLES=OFF \
  -DZLIB_INCLUDE_DIR="$DEPS_INCLUDE" -DZLIB_LIBRARY="$DEPS_LIB/libz.a" \
cmake --build build-ios -j"$(nproc)"
cmake --install build-ios
