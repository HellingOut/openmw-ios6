#!/bin/bash
# Build the Boost subset used by OpenMW 0.46 for iOS 6 / armv7.
# Boost.Build is macOS-oriented (it shells out to xcrun), so compile the few
# required libraries directly with the cross compiler instead.
set -euo pipefail
source "$(dirname "$0")/env.sh"
BOOST="$DEPS_SRC/boost_1_78_0"
BUILD="$BOOST/build-ios"
rm -rf "$BUILD"
mkdir -p "$BUILD"

DEFS="-DBOOST_ALL_NO_LIB -DBOOST_SYSTEM_STATIC_LINK -DBOOST_FILESYSTEM_STATIC_LINK \
-DBOOST_PROGRAM_OPTIONS_STATIC_LINK -DBOOST_IOSTREAMS_STATIC_LINK \
-DBOOST_IOSTREAMS_NO_BZIP2 -DBOOST_IOSTREAMS_NO_LZMA -DBOOST_IOSTREAMS_NO_ZSTD -DBOOST_FILESYSTEM_NO_CXX20_ATOMIC_REF"
INCS="-I$BOOST -I$DEPS_INCLUDE"
CXXFLAGS="-std=gnu++14 -O2 -fPIC -fvisibility=hidden -Wno-deprecated-declarations $IOS_COMPAT_DEFS $DEFS $INCS"

build_lib() {
  local name="$1"; shift
  local out="$BUILD/$name"
  mkdir -p "$out"
  local objs=()
  for src in "$@"; do
    local obj="$out/$(basename "${src%.cpp}").o"
    "$DEPS_DIR/toolchain/cxx-ios" $CXXFLAGS -c "$src" -o "$obj"
    objs+=("$obj")
  done
  "$IOS_TC/ar" rcs "$DEPS_LIB/libboost_$name.a" "${objs[@]}"
  "$IOS_TC/ranlib" "$DEPS_LIB/libboost_$name.a"
}

build_lib system "$BOOST/libs/system/src/error_code.cpp"
build_lib filesystem \
  "$BOOST/libs/filesystem/src/codecvt_error_category.cpp" \
  "$BOOST/libs/filesystem/src/directory.cpp" \
  "$BOOST/libs/filesystem/src/exception.cpp" \
  "$BOOST/libs/filesystem/src/operations.cpp" \
  "$BOOST/libs/filesystem/src/path.cpp" \
  "$BOOST/libs/filesystem/src/path_traits.cpp" \
  "$BOOST/libs/filesystem/src/portability.cpp" \
  "$BOOST/libs/filesystem/src/unique_path.cpp" \
  "$BOOST/libs/filesystem/src/utf8_codecvt_facet.cpp"
build_lib program_options \
  "$BOOST/libs/program_options/src/cmdline.cpp" \
  "$BOOST/libs/program_options/src/config_file.cpp" \
  "$BOOST/libs/program_options/src/convert.cpp" \
  "$BOOST/libs/program_options/src/options_description.cpp" \
  "$BOOST/libs/program_options/src/parsers.cpp" \
  "$BOOST/libs/program_options/src/positional_options.cpp" \
  "$BOOST/libs/program_options/src/split.cpp" \
  "$BOOST/libs/program_options/src/utf8_codecvt_facet.cpp" \
  "$BOOST/libs/program_options/src/value_semantic.cpp" \
  "$BOOST/libs/program_options/src/variables_map.cpp"
build_lib iostreams \
  "$BOOST/libs/iostreams/src/file_descriptor.cpp" \
  "$BOOST/libs/iostreams/src/gzip.cpp" \
  "$BOOST/libs/iostreams/src/mapped_file.cpp" \
  "$BOOST/libs/iostreams/src/zlib.cpp"

# Headers
rm -rf "$DEPS_INCLUDE/boost"
cp -R "$BOOST/boost" "$DEPS_INCLUDE/boost"
echo "Boost installed to $DEPS_LIB and $DEPS_INCLUDE/boost"
