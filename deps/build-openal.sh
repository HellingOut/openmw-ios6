#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/openal-soft-1.21.1"
cmake -S . -B build-ios "${ios_cmake_common[@]}" \
  -DLIBTYPE=STATIC \
  -DALSOFT_EXAMPLES=OFF -DALSOFT_UTILS=OFF -DALSOFT_TESTS=OFF \
  -DALSOFT_BACKEND_COREAUDIO=ON -DALSOFT_REQUIRE_COREAUDIO=ON \
  -DALSOFT_BACKEND_WAVE=ON \
  -DALSOFT_STATIC_LIBGCC=OFF \
  -DCMAKE_C_FLAGS="$CFLAGS -I$DEPS_INCLUDE" \
  -DCMAKE_CXX_FLAGS="$CXXFLAGS -Dthread_local= -I$DEPS_INCLUDE"
cmake --build build-ios -j"${OPENAL_JOBS:-2}"
cmake --install build-ios
