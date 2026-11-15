#!/bin/bash
# GL4ES translates OpenMW's desktop OpenGL 2.1 calls to OpenGL ES 2.0.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/gl4es-master"
cmake -S . -B build-ios "${ios_cmake_common[@]}" \
  -DSTATICLIB=ON \
  -DNOX11=ON -DNOEGL=ON -DNO_GBM=ON -DNO_LOADER=ON \
  -DGLX_STUBS=ON \
  -DCMAKE_C_FLAGS="$CFLAGS -I$DEPS_INCLUDE"
cmake --build build-ios -j"$(nproc)"
cp lib/libGL.a "$DEPS_LIB/libGL.a"
"$IOS_TC/ranlib" "$DEPS_LIB/libGL.a"
mkdir -p "$DEPS_INCLUDE/GL" "$DEPS_INCLUDE/GLES" "$DEPS_INCLUDE/KHR"
cp -R include/GL/. "$DEPS_INCLUDE/GL/"
cp -R include/GLES/. "$DEPS_INCLUDE/GLES/"
cp -R include/KHR/. "$DEPS_INCLUDE/KHR/"
cp include/gl4eshint.h include/gl4esinit.h "$DEPS_INCLUDE/" 2>/dev/null || true
echo "gl4es installed to $DEPS_LIB/libGL.a"
