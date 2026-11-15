# Shared environment for building iOS 6 / armv7 dependencies.
# Source this file from deps/build-*.sh scripts.
export THEOS="${THEOS:-$HOME/theos}"
export IOS_SDKVERSION="${IOS_SDKVERSION:-7.1}"
export IOS_DEPLOYMENT="${IOS_DEPLOYMENT:-6.0}"
export IOS_ARCH="${IOS_ARCH:-armv7}"
export IOS_SDK_PATH="$THEOS/sdks/iPhoneOS${IOS_SDKVERSION}.sdk"
export IOS_TC="$THEOS/toolchain/linux/iphone/bin"

DEPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEPS_DIR
export DEPS_SRC="$DEPS_DIR/src"
export DEPS_DOWNLOADS="$DEPS_DIR/downloads"
export DEPS_PREFIX="$DEPS_DIR"
export DEPS_INCLUDE="$DEPS_DIR/include"
export DEPS_LIB="$DEPS_DIR/lib"

# The iOS 7.1 SDK predates these TargetConditionals macros; clang 13 treats
# their absence as an error for Apple targets.
IOS_COMPAT_DEFS="-D__IPHONEOS__=1 -DTARGET_OS_TV=0 -DTARGET_OS_WATCH=0 -DTARGET_OS_IOS=1 -DTARGET_OS_MACCATALYST=0 -DTARGET_OS_SIMULATOR=0"

add_flag() { # add_flag VAR FLAGS
  local var="$1" flags="$2"
  if [ -n "${!var:-}" ]; then
    printf -v "$var" '%s %s' "$flags" "${!var}"
  else
    printf -v "$var" '%s' "$flags"
  fi
}
add_flag CPPFLAGS "-I$DEPS_INCLUDE $IOS_COMPAT_DEFS"
add_flag CFLAGS "-O2 -fPIC -Wno-deprecated-declarations -Wno-unused-command-line-argument $IOS_COMPAT_DEFS"
add_flag CXXFLAGS "-O2 -fPIC -stdlib=libc++ -DMYGUI_DONT_REPLACE_NULLPTR -Wno-deprecated-declarations -Wno-unused-command-line-argument $IOS_COMPAT_DEFS"
add_flag LDFLAGS "-L$DEPS_LIB"
export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS

ios_cmake_common=(
  -DCMAKE_TOOLCHAIN_FILE="$DEPS_DIR/toolchain/ios.toolchain.cmake"
  -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX"
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DCMAKE_PREFIX_PATH="$DEPS_PREFIX"
  -DCMAKE_FIND_ROOT_PATH="$DEPS_PREFIX;$IOS_SDK_PATH"
  -DCMAKE_C_FLAGS="$CFLAGS -I$DEPS_INCLUDE"
  -DCMAKE_CXX_FLAGS="$CXXFLAGS -I$DEPS_INCLUDE"
  -DCMAKE_OBJC_FLAGS="$CFLAGS -I$DEPS_INCLUDE"
  -DCMAKE_OBJCXX_FLAGS="$CXXFLAGS -I$DEPS_INCLUDE"
)
export ios_cmake_common
