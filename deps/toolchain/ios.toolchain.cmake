# CMake toolchain for cross-compiling iOS 6 / armv7 dependencies with Theos clang.
# Usage:
#   cmake -DCMAKE_TOOLCHAIN_FILE=<this file> -DCMAKE_INSTALL_PREFIX=<deps> ...
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_OSX_ARCHITECTURES armv7)
set(CMAKE_OSX_DEPLOYMENT_TARGET 6.0)
set(CMAKE_OSX_SYSROOT "$ENV{HOME}/theos/sdks/iPhoneOS7.1.sdk")

set(_tc "$ENV{HOME}/theos/toolchain/linux/iphone/bin")
set(CMAKE_C_COMPILER "${CMAKE_CURRENT_LIST_DIR}/cc-ios")
set(CMAKE_CXX_COMPILER "${CMAKE_CURRENT_LIST_DIR}/cxx-ios")
set(CMAKE_AR "${_tc}/ar" CACHE FILEPATH "Archiver")
set(CMAKE_RANLIB "${_tc}/ranlib" CACHE FILEPATH "Ranlib")
set(CMAKE_STRIP "${_tc}/strip" CACHE FILEPATH "Strip")
set(CMAKE_INSTALL_NAME_TOOL "${_tc}/install_name_tool" CACHE FILEPATH "install_name_tool")

# Cross-compiling: try_compile may link, but never run test binaries.
set(CMAKE_TRY_COMPILE_TARGET_TYPE EXECUTABLE)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(CMAKE_C_FLAGS_INIT "-Wno-deprecated-declarations -Wno-unused-command-line-argument -D__IPHONEOS__=1 -DTARGET_OS_TV=0 -DTARGET_OS_WATCH=0 -DTARGET_OS_IOS=1 -DTARGET_OS_MACCATALYST=0 -DTARGET_OS_SIMULATOR=0")
set(CMAKE_CXX_FLAGS_INIT "-Wno-deprecated-declarations -Wno-unused-command-line-argument -D__IPHONEOS__=1 -DTARGET_OS_TV=0 -DTARGET_OS_WATCH=0 -DTARGET_OS_IOS=1 -DTARGET_OS_MACCATALYST=0 -DTARGET_OS_SIMULATOR=0")

# iOS CMake targets default to .app bundles for executables; dependencies only
# build static libraries and the build tools are not needed on device.
set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO)
