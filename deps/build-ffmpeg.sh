#!/bin/bash
# Build a static FFmpeg 4.4 for iOS 6 / armv7 (decoders only, no asm).
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$DEPS_SRC/FFmpeg-n4.4"
make distclean >/dev/null 2>&1 || true
./configure \
  --prefix="$DEPS_PREFIX" \
  --target-os=darwin --arch=arm --cpu=armv7-a \
  --enable-cross-compile \
  --cc="$DEPS_DIR/toolchain/cc-ios" \
  --ar="$IOS_TC/ar" --ranlib="$IOS_TC/ranlib" --nm="$IOS_TC/nm" \
  --cxx="$DEPS_DIR/toolchain/cxx-ios" \
  --sysroot="$IOS_SDK_PATH" \
  --extra-cflags="-O2 -fPIC $IOS_COMPAT_DEFS -Wno-deprecated-declarations" \
  --extra-ldflags="-L$DEPS_LIB" \
  --enable-static --disable-shared --enable-pic \
  --disable-asm --disable-neon \
  --disable-programs --disable-doc --disable-debug \
  --disable-avdevice --disable-postproc --disable-network \
  --disable-encoders --disable-muxers --disable-filters \
  --disable-indevs --disable-outdevs \
  --disable-iconv --disable-xlib --disable-zlib --disable-bzlib --disable-lzma \
  --disable-videotoolbox --disable-audiotoolbox
make -j"${FFMPEG_JOBS:-4}"
make install
