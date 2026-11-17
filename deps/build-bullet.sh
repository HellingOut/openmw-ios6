#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/bullet3-2.89"

# btScalar precision: 0 = float (default), 1 = double. Must match
# BT_DOUBLE_PRECISION in the Makefile; the Makefile's before-all guard checks
# libLinearMath.a's btConvexHullComputer::compute() mangling.
BT_DOUBLE_PRECISION="${BT_DOUBLE_PRECISION:-0}"
case "$BT_DOUBLE_PRECISION" in
  0) USE_DOUBLE_PRECISION=OFF; build_dir=build-ios-float ;;
  1) USE_DOUBLE_PRECISION=ON;  build_dir=build-ios-double ;;
  *)
    echo "build-bullet.sh: BT_DOUBLE_PRECISION must be 0 or 1 (got '$BT_DOUBLE_PRECISION')" >&2
    exit 1
    ;;
esac

if [ "$USE_DOUBLE_PRECISION" = ON ]; then
  echo "==> Bullet: btScalar is double (USE_DOUBLE_PRECISION=ON, $build_dir)"
else
  echo "==> Bullet: btScalar is float (USE_DOUBLE_PRECISION=OFF, $build_dir)"
fi

# A build tree copied from another checkout carries a stale absolute
# CMAKE_HOME_DIRECTORY and stale objects; never reuse it.
if [ -f "$build_dir/CMakeCache.txt" ]; then
  cached_home="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$build_dir/CMakeCache.txt")"
  if [ "$cached_home" != "$PWD" ]; then
    echo "==> Removing stale $build_dir (configured in '${cached_home:-unknown}')"
    rm -rf "$build_dir"
  fi
fi

cmake -S . -B "$build_dir" "${ios_cmake_common[@]}" \
  -DBUILD_SHARED_LIBS=OFF \
  -DUSE_DOUBLE_PRECISION="$USE_DOUBLE_PRECISION" \
  -DBUILD_BULLET2_DEMOS=OFF -DBUILD_BULLET3=OFF -DBUILD_CPU_DEMOS=OFF \
  -DBUILD_OPENGL3_DEMOS=OFF -DBUILD_EXTRAS=OFF -DBUILD_UNIT_TESTS=OFF \
  -DBUILD_CLSOCKET=OFF -DBUILD_ENET=OFF -DINSTALL_LIBS=ON
cmake --build "$build_dir" -j"$(nproc)"
cmake --install "$build_dir"
