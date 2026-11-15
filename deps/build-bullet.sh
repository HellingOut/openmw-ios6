#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/bullet3-2.89"
cmake -S . -B build-ios "${ios_cmake_common[@]}" \
  -DBUILD_SHARED_LIBS=OFF \
  -DUSE_DOUBLE_PRECISION=ON \
  -DBUILD_BULLET2_DEMOS=OFF -DBUILD_BULLET3=OFF -DBUILD_CPU_DEMOS=OFF \
  -DBUILD_OPENGL3_DEMOS=OFF -DBUILD_EXTRAS=OFF -DBUILD_UNIT_TESTS=OFF \
  -DBUILD_CLSOCKET=OFF -DBUILD_ENET=OFF -DINSTALL_LIBS=ON
cmake --build build-ios -j"$(nproc)"
cmake --install build-ios
