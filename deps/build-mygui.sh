#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/mygui-MyGUI3.2.2"
cmake -S . -B build-ios "${ios_cmake_common[@]}" \
  -DMYGUI_STATIC=TRUE -DBUILD_SHARED_LIBS=OFF \
  -DMYGUI_RENDERSYSTEM=1 \
  -DMYGUI_USE_FREETYPE=TRUE \
  -DFREETYPE_INCLUDE_DIRS="$DEPS_INCLUDE/freetype2" \
  -DFREETYPE_LIBRARY="$DEPS_LIB/libfreetype.a" \
  -DMYGUI_BUILD_DEMOS=OFF -DMYGUI_BUILD_PLUGINS=OFF \
  -DMYGUI_BUILD_TOOLS=OFF -DMYGUI_BUILD_UNITTESTS=OFF \
  -DMYGUI_BUILD_TEST_APP=OFF -DMYGUI_BUILD_WRAPPER=OFF \
  -DMYGUI_INSTALL_MEDIA=OFF
cmake --build build-ios -j"$(nproc)"
cmake --install build-ios
