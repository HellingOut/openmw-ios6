#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/libjpeg-turbo-2.1.4"
cmake -S . -B build-ios "${ios_cmake_common[@]}" \
  -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
  -DWITH_SIMD=OFF -DWITH_TURBOJPEG=OFF -DWITH_JAVA=OFF -DWITH_TOOLS=OFF -DWITH_TESTS=OFF
cmake --build build-ios -j"$(nproc)"
cmake --install build-ios
