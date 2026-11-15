#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/zlib-1.2.13"
cmake -S . -B build-ios "${ios_cmake_common[@]}" \
  -DBUILD_SHARED_LIBS=OFF \
  -DZLIB_BUILD_EXAMPLES=OFF \
cmake --build build-ios -j"$(nproc)"
cmake --install build-ios
