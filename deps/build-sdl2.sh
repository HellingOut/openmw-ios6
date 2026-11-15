#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/SDL2-2.0.9"
cmake -S . -B build-ios "${ios_cmake_common[@]}" \
  -DIOS=TRUE \
  -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF \
  -DSDL_HAPTIC=ON -DSDL_POWER=ON
# SDL's CMake-generated config is macOS-oriented for !IOS; the hand-maintained
# iphoneos config is the one used by SDL's own Xcode project and enables the
# UIKit video/audio/joystick/power backends.
cp include/SDL_config_iphoneos.h build-ios/include/SDL_config.h
# CMake marks the UIKit .m sources as LANGUAGE C and therefore never passes the
# ObjC ARC flag; the UIKit backend requires ARC.
sed -i 's/^\(C_FLAGS[^=]*= .*\)$/\1 -fobjc-arc/' build-ios/CMakeFiles/SDL2-static.dir/flags.make
cmake --build build-ios -j"${SDL_JOBS:-2}"
cmake --install build-ios
