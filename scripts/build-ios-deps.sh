#!/bin/bash
# Download sources (if needed) and build every native dependency for
# iOS 6 / armv7 into deps/include and deps/lib.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export THEOS="${THEOS:-$HOME/theos}"
export IOS_SDKVERSION="${IOS_SDKVERSION:-7.1}"
export IOS_DEPLOYMENT="${IOS_DEPLOYMENT:-6.0}"
export IOS_ARCH="${IOS_ARCH:-armv7}"

# Bullet btScalar precision, forwarded to deps/build-bullet.sh.
# 0 = float (default), 1 = double. The Makefile passes this in the environment.
export BT_DOUBLE_PRECISION="${BT_DOUBLE_PRECISION:-0}"
case "$BT_DOUBLE_PRECISION" in
  0|1) ;;
  *)
    echo "build-ios-deps.sh: BT_DOUBLE_PRECISION must be 0 or 1 (got '$BT_DOUBLE_PRECISION')" >&2
    exit 1
    ;;
esac

DL="$ROOT/deps/downloads"
SRC="$ROOT/deps/src"
mkdir -p "$DL" "$SRC"

fetch() { # fetch <url> <filename> <archive-dir-name>
  local url="$1" file="$2" dir="$3"
  if [ ! -f "$DL/$file" ]; then
    echo "==> Downloading $file"
    curl -fL --retry 3 -o "$DL/$file" "$url"
  fi
  if [ ! -d "$SRC/$dir" ]; then
    echo "==> Extracting $file"
    case "$file" in
      *.tar.gz|*.tgz) tar xzf "$DL/$file" -C "$SRC" ;;
      *.tar.bz2)      tar xjf "$DL/$file" -C "$SRC" ;;
      *.zip)          unzip -q "$DL/$file" -d "$SRC" ;;
    esac
  fi
}

fetch https://github.com/madler/zlib/archive/refs/tags/v1.2.13.tar.gz \
      v1.2.13.tar.gz zlib-1.2.13
fetch https://github.com/glennrp/libpng/archive/refs/tags/v1.6.37.tar.gz \
      v1.6.37.tar.gz libpng-1.6.37
fetch https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/2.1.4.tar.gz \
      2.1.4.tar.gz libjpeg-turbo-2.1.4
fetch https://github.com/freetype/freetype/archive/refs/tags/VER-2-11-1.tar.gz \
      VER-2-11-1.tar.gz freetype-VER-2-11-1
fetch https://github.com/libsdl-org/SDL/releases/download/release-2.0.9/SDL2-2.0.9.tar.gz \
      SDL2-2.0.9.tar.gz SDL2-2.0.9
fetch https://archives.boost.io/release/1.78.0/source/boost_1_78_0.tar.bz2 \
      boost_1_78_0.tar.bz2 boost_1_78_0
fetch https://github.com/bulletphysics/bullet3/archive/refs/tags/2.89.tar.gz \
      2.89.tar.gz bullet3-2.89
fetch https://github.com/MyGUI/mygui/archive/refs/tags/MyGUI3.2.2.tar.gz \
      MyGUI3.2.2.tar.gz mygui-MyGUI3.2.2
fetch https://github.com/openscenegraph/OpenSceneGraph/archive/refs/tags/OpenSceneGraph-3.4.1.tar.gz \
      OpenSceneGraph-3.4.1.tar.gz OpenSceneGraph-OpenSceneGraph-3.4.1
fetch https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n4.4.tar.gz \
      n4.4.tar.gz FFmpeg-n4.4
fetch https://github.com/kcat/openal-soft/archive/refs/tags/1.21.1.tar.gz \
      1.21.1.tar.gz openal-soft-1.21.1
# gl4es is pinned to a commit: upstream master changes frequently.
GL4ES_COMMIT=8b1a3da5d2331d0f88b70be25963182d46eed857
if [ ! -d "$SRC/gl4es-master" ]; then
  fetch "https://github.com/ptitSeb/gl4es/archive/${GL4ES_COMMIT}.tar.gz" \
        "gl4es-${GL4ES_COMMIT}.tar.gz" "gl4es-${GL4ES_COMMIT}"
  mv "$SRC/gl4es-${GL4ES_COMMIT}" "$SRC/gl4es-master"
fi

# Dependency patches (idempotent: reset tracked sources first when possible).
"$ROOT/deps/apply-patches.sh"

for step in zlib libpng libjpeg freetype sdl2 boost bullet mygui gl4es osg ffmpeg openal; do
  echo "==> Building $step"
  "$ROOT/deps/build-$step.sh"
done

# Keep only static libraries; all third-party code is linked into the app.
find "$ROOT/deps/lib" -maxdepth 1 -name '*.dylib' -delete
rm -rf "$ROOT/deps/SDL2.framework"

echo "All dependencies built in $ROOT/deps (BT_DOUBLE_PRECISION=$BT_DOUBLE_PRECISION)"
