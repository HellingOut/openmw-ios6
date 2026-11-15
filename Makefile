# Theos Makefile for OpenMW 0.46 (iOS 6+, armv7)
#
# Targets:
#   make                 - build OpenMW.app
#   make deps            - download/build all iOS dependencies into deps/
#   make package         - build a .deb
#   make package PACKAGE_FORMAT=ipa  - build an .ipa
#   make ipa             - same as above
#
# The prebuilt static libraries and headers live in $(IOS_DEPS_DIR)
# (deps/ by default).  All third-party libraries are linked statically.

IOS_SDKVERSION ?= 7.1
IOS_DEPLOYMENT ?= 6.0
IOS_ARCH ?= armv7

TARGET = iphone:clang:$(IOS_SDKVERSION):$(IOS_DEPLOYMENT)
ARCHS = $(IOS_ARCH)

# Legacy code base: warnings must not become errors.
GO_EASY_ON_ME = 1

include $(THEOS)/makefiles/common.mk

IOS_DEPS_DIR ?= $(THEOS_PROJECT_DIR)/deps
IOS_DEPS_LIB = $(IOS_DEPS_DIR)/lib
IOS_DEPS_INC = $(IOS_DEPS_DIR)/include

APPLICATION_NAME = openmw

# Only the engine is built; launcher/opencs/wizard need Qt and are not part of
# the iOS port.  Qt-only component directories are excluded.
openmw_FILES = \
	$(shell find apps/openmw -name '*.cpp' ! -name 'android_main.cpp') \
	$(THEOS_PROJECT_DIR)/components/sdlutil/ios_render_scale.mm \
	$(shell find components -name '*.cpp' \
		! -name 'gen_iconv.cpp' \
		! -path '*/tests/*' \
		! -path 'components/config/*' \
		! -path 'components/contentselector/*' \
		! -path 'components/crashcatcher/*' \
		! -path 'components/process/*') \
	$(shell find extern/oics extern/osg-ffmpeg-videoplayer extern/recastnavigation -name '*.cpp')

IOS_COMPAT_DEFS = -D__IPHONEOS__=1 -DTARGET_OS_TV=0 -DTARGET_OS_WATCH=0 -DTARGET_OS_IOS=1 \
	-DTARGET_OS_MACCATALYST=0 -DTARGET_OS_SIMULATOR=0

COMMON_DEFS = $(IOS_COMPAT_DEFS) \
	-DOSG_LIBRARY_STATIC -DMYGUI_STATIC -DMYGUI_DONT_REPLACE_NULLPTR \
	-DBOOST_ALL_NO_LIB -DBOOST_NO_CXX11_SCOPED_ENUMS=ON \
	-D__STDC_CONSTANT_MACROS -DBT_USE_DOUBLE_PRECISION

COMMON_INCLUDES = \
	-I$(THEOS_PROJECT_DIR) \
	-I$(IOS_DEPS_INC) \
	-I$(IOS_DEPS_INC)/MYGUI \
	-I$(IOS_DEPS_INC)/SDL2 \
	-I$(IOS_DEPS_INC)/AL \
	-I$(IOS_DEPS_INC)/freetype2 \
	-I$(IOS_DEPS_INC)/bullet \
	-I$(THEOS_PROJECT_DIR)/extern/recastnavigation/Detour/Include \
	-I$(THEOS_PROJECT_DIR)/extern/recastnavigation/DetourCrowd/Include \
	-I$(THEOS_PROJECT_DIR)/extern/recastnavigation/DetourTileCache/Include \
	-I$(THEOS_PROJECT_DIR)/extern/recastnavigation/Recast/Include \
	-I$(THEOS_PROJECT_DIR)/extern/recastnavigation/DebugUtils/Include \
	-I$(THEOS_PROJECT_DIR)/extern/oics \
	-I$(THEOS_PROJECT_DIR)/extern/osg-ffmpeg-videoplayer

COMMON_WARNINGS = \
	-Wno-deprecated-declarations -Wno-unused-parameter -Wno-unused-variable \
	-Wno-unused-but-set-variable -Wno-sign-compare -Wno-format \
	-Wno-char-subscripts -Wno-multichar -Wno-switch -Wno-unknown-pragmas \
	-Wno-parentheses -Wno-missing-field-initializers -Wno-unused-function \
	-Wno-unused-value -Wno-logical-op-parentheses -Wno-constant-logical-operand \
	-Wno-invalid-offsetof -Wno-unused-private-field -Wno-unused-lambda-capture \
	-Wno-undefined-var-template -Wno-inconsistent-missing-override \
	-Wno-potentially-evaluated-expression -Wno-delete-non-virtual-dtor \
	-Wno-overloaded-virtual -Wno-absolute-value -Wno-return-type \
	-Wno-unused-result

openmw_CFLAGS = $(COMMON_DEFS) $(COMMON_INCLUDES) $(COMMON_WARNINGS)
openmw_CCFLAGS = -std=gnu++14 -stdlib=libc++

# Static libraries are force-loaded: Theos puts LDFLAGS before object files and
# Darwin's linker does not revisit an archive.
define force_load
-Wl,-force_load,$(IOS_DEPS_LIB)/lib$(1).a
endef
define force_load_path
-Wl,-force_load,$(1)
endef

OSG_LIBS = OpenThreads osg osgDB osgUtil osgGA osgText osgViewer osgParticle osgFX osgShadow osgAnimation
OSG_PLUGIN_DIR = $(IOS_DEPS_LIB)/osgPlugins-3.4.1
OSG_PLUGINS = osgdb_bmp osgdb_dds osgdb_freetype osgdb_jpeg osgdb_osg osgdb_png osgdb_serializers_osg osgdb_tga
BOOST_LIBS = boost_system boost_filesystem boost_program_options boost_iostreams
BULLET_LIBS = BulletCollision LinearMath
FFMPEG_LIBS = avcodec avformat avutil swscale swresample
MISC_LIBS = SDL2 GL MyGUIEngineStatic openal freetype jpeg png16 z

openmw_LDFLAGS = -L$(IOS_DEPS_LIB) -stdlib=libc++ -liconv \
	$(foreach l,$(OSG_LIBS) $(BOOST_LIBS) $(BULLET_LIBS) $(FFMPEG_LIBS) $(MISC_LIBS),$(call force_load,$(l))) \
	$(foreach l,$(OSG_PLUGINS),$(call force_load_path,$(OSG_PLUGIN_DIR)/lib$(l).a))

openmw_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore OpenGLES \
	CoreAudio AudioToolbox AVFoundation CoreVideo CoreMedia \
	CoreMotion GameController ImageIO MobileCoreServices CoreText Security \
	Accelerate

openmw_BUNDLE_NAME = OpenMW
openmw_INSTALL_PATH = /Applications
openmw_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/application.mk

### Packaging ################################################################

ipa: all
	@rm -rf "$(THEOS_STAGING_DIR)"
	@$(MAKE) -f $(firstword $(MAKEFILE_LIST)) package PACKAGE_FORMAT=ipa

### Dependencies #############################################################

deps:
	@THEOS="$(THEOS)" IOS_SDKVERSION="$(IOS_SDKVERSION)" IOS_ARCH="$(IOS_ARCH)" \
		IOS_DEPLOYMENT="$(IOS_DEPLOYMENT)" \
		"$(THEOS_PROJECT_DIR)/scripts/build-ios-deps.sh"

### Pre-build checks / resource staging ######################################

before-all::
	@missing=0; for lib in SDL2 GL osg osgDB osgUtil osgGA osgViewer MyGUIEngineStatic \
		boost_system boost_filesystem boost_program_options boost_iostreams \
		BulletCollision LinearMath avcodec avformat avutil swscale swresample \
		openal freetype jpeg png16 z; do \
		if [ ! -f "$(IOS_DEPS_LIB)/lib$$lib.a" ]; then \
			$(PRINT_FORMAT_ERROR) "Missing dependency: lib$$lib.a" >&2; missing=1; \
		fi; \
	done; \
	if [ ! -f "$(OSG_PLUGIN_DIR)/libosgdb_png.a" ]; then \
		$(PRINT_FORMAT_ERROR) "Missing OSG plugin: libosgdb_png.a" >&2; missing=1; \
	fi; \
	if [ $$missing -ne 0 ]; then \
		$(PRINT_FORMAT_ERROR) "Run 'make deps' first (or set IOS_DEPS_DIR)." >&2; \
		exit 1; \
	fi
	@THEOS_PROJECT_DIR="$(THEOS_PROJECT_DIR)" IOS_DEPS_DIR="$(IOS_DEPS_DIR)" \
		"$(THEOS_PROJECT_DIR)/scripts/stage-resources.sh"
