# OpenMW iOS 6 port

This branch ports OpenMW **0.46** to **iOS 6 / armv7** using the Theos build
system. It builds a signed `OpenMW.app` and an unsigned `.ipa`; the launcher,
OpenMW-CS and the installation wizard (which require Qt) are not part of the
port.

## Requirements

- Theos with `iPhoneOS7.1.sdk` and the Linux clang toolchain.
- `cmake`, `ninja`/`make`, `git`, `curl`, a C/C++ host toolchain.
- About 4 GB of disk space for sources and build trees.

The target is `iphone:clang:7.1:6.0`, `ARCHS = armv7`. The resulting binary has
`LC_VERSION_MIN_IPHONEOS 6.0` and runs on 32-bit iOS (6 through 10).

## Building

```sh
export THEOS=$HOME/theos
make deps                       # downloads and builds all native dependencies
make package PACKAGE_FORMAT=ipa # builds packages/org.openmw.ios6_*.ipa
# For a playable (optimised) build:
make package PACKAGE_FORMAT=ipa DEBUG=0
```

`make deps` is only needed once (or after changing a dependency). All
third-party libraries are installed as static archives in `deps/lib` and
headers in `deps/include`; they are force-loaded into the application. The
resulting executable links only against iOS system frameworks and libSystem.

Dependencies built by `make deps`:

| Library | Version | Notes |
| --- | --- | --- |
| zlib | 1.2.13 | static |
| libpng | 1.6.37 | static, no ARM NEON |
| libjpeg-turbo | 2.1.4 | static, no SIMD |
| FreeType | 2.11.1 | static |
| SDL2 | 2.0.9 | UIKit video/audio/power/MFi backends |
| Boost | 1.78.0 | system, filesystem, program_options, iostreams |
| Bullet | 2.89 | static, double precision |
| MyGUI | 3.2.2 | engine only (OpenMW provides the OSG platform) |
| OpenSceneGraph | 3.4.1 | static, GL2 profile, image plugins only |
| FFmpeg | 4.4 | static, decoders only, no assembly |
| OpenAL Soft | 1.21.1 | static, CoreAudio backend |
| GL4ES | pinned commit | desktop OpenGL 2.x → OpenGL ES 2.0 |

The small portability patches live in `deps/patches`; `make deps` applies them
automatically and is safe to re-run.

### Bullet precision

- Default is **single precision**: `BT_DOUBLE_PRECISION=0` in the Makefile,
  `USE_DOUBLE_PRECISION=OFF` for the Bullet build (`btScalar` is `float`).
- This matches the engine, which is `float` throughout (`osg::Vec3f`,
  `ESM::Position`), and on armv7 it enables Bullet's NEON `btVector3` SIMD path.
- Double precision build: `BT_DOUBLE_PRECISION=1 make deps`, then `make`.
- The `before-all` step checks `libLinearMath.a` for the
  `btConvexHullComputer::compute()` mangling (`...idd` for double, `...iff` for
  float) and stops the build with an error if the archives and the compile
  flags disagree. Re-run `BT_DOUBLE_PRECISION=0 make deps` (or `=1`) to fix it.

## Layout in the application bundle

```
OpenMW.app/
  openmw              # SDL calls SDL_main() from apps/openmw/main.cpp
  Info.plist
  assets/
    mygui/ shaders/ vfs/
    settings-default.cfg openmw.cfg version gamecontrollerdb.txt
```

The engine changes the working directory to the bundle path with
`SDL_GetBasePath()` before reading its configuration, so `resources` resolves
relative to the `.app`. The directory is deliberately named `assets`:
iOS 8.4.1 installd rejects a top-level folder literally named `resources`.


## Port-specific source changes

- `apps/openmw/main.cpp` — `SDL_main` entry point on iOS, bundle-relative cwd.
- `components/nif/nifstream.hpp` — `skip()` reads and discards bytes instead of
  calling `istream::ignore()`. libc++ compares every byte against
  `traits_type::eof()`, and on Apple platforms `char` is signed, so a `0xFF`
  byte compares equal to `eof()` (`-1`) and `ignore()` stops after a single
  byte. Morrowind NIFs contain such bytes — `NiSkinData`'s "no NiSkinPartition"
  link is `0xFFFFFFFF` — so the record stream silently desynchronised by three
  bytes. Every skinned mesh then failed to load with
  `Record number N out of M is blank` (or `Found no root nodes`): the player
  body, clothing and the first-person mesh all fell back to `marker_error.nif`,
  and starting a new game aborted. Linux/libstdc++ is unaffected because it maps
  bytes through `unsigned char`.
- `apps/openmw/mwphysics/heightfield.cpp` — terrain heights are copied into a
  `std::vector<btScalar>` before being handed to `btHeightfieldTerrainShape`.
  Bullet 2.89 declares that buffer as `const btScalar*` but the data as
  `PHY_FLOAT`, so the element type must be `btScalar`, not `float`. The copy is
  what makes the shape correct at either precision: with double-precision Bullet
  it widens the game's `float` heights instead of letting Bullet read 8 bytes
  per vertex and step over every second one, and under the default
  single-precision build the cast is a no-op. Reading the buffer at the wrong
  stride produced a garbage collision mesh: the player fell through all terrain,
  and the degenerate "contacts" it produced could throw the actor millions of
  units away (only the skybox visible).
- `apps/openmw/mwphysics/movementsolver.cpp` — the "unstuck" separation offset is
  range-checked before it is applied, so an absurd contact point can no longer be
  amplified into the actor's position.
- `components/detournavigator/recastglobalallocator.hpp` — pthread-key
  substitute for `thread_local` (iOS 6 has no TLS support).
- `components/detournavigator/recastmeshbuilder.cpp` — explicit `btScalar`
  template arguments for double-precision Bullet.
- `components/crashcatcher/crashcatcher.hpp` — the Linux/macOS crash handler is
  disabled on iOS (it needs `libproc.h`, which iOS does not provide).
- `components/sdlutil/sdlgraphicswindow.cpp` — the EAGL drawable colour buffer
  is re-bound before `SDL_GL_SwapWindow`. SDL presents whatever renderbuffer is
  currently bound, while OSG leaves the renderbuffer of the last FBO camera
  bound, which froze the display on the loading screen after the first frame
  buffer object was used.
- `deps/patches/gl4es-master-src-gl-framebuffers.c.patch` — gl4es accepts
  renderbuffer ids it did not create, so the SDL/UIKit drawable colour buffer
  can be bound again (see the entry above).
- `apps/openmw/mwinput/touchcontrols.cpp` — a virtual **BACK** button that sends
  `Escape` is the only button kept visible while a GUI window is open. Without it
  menus were a dead end: the touch layer hides every virtual button in GUI mode
  and turns the first finger into a mouse click, so nothing could close the
  window again and the port has no physical Escape key.

## iOS screen size / rotation stability

After using Notification Center or Control Center, or after switching away
from and back to the app, the rendered picture could jump or be cropped, touch
input could go dead on one half of the screen, and in the worst case the whole
device (SpringBoard) froze.

The root cause is that UIKit can swap the EAGL view's bounds between
1024x768 and 768x1024 during a resign/activate cycle while leaving the
90-degree rotation transform in place. `view.frame` then grew beyond
`UIWindow.bounds` and was clipped. On the engine side, OSG's camera viewport
only followed SDL `RESIZED` events while MyGUI consumed SDL's window size, so
the two disagreed. Presenting a drawable whose size no longer matched the
layer wedged the PowerVR driver; the crash reports showed this as an
`EXC_BAD_ACCESS` in `IMGSGX554GLDriver`.

The fix has several cooperating parts:

- `SDL_uikitopenglview.m` — `layoutSubviews` keeps `view.frame` equal to
  `window.bounds`, deriving the view bounds through the inverse of the rotation
  transform; `swapBuffers` re-creates the drawable when it disagrees with the
  current view bounds and rebinds it before presenting.
- `SDL_uikitvideo.m` — `UIKit_ComputeViewFrame` prefers the `UIWindow` bounds
  over the `UIScreen` bounds, with a fullscreen guard so that only a truly
  fullscreen window is orientation-swapped.
- `SDL_uikitviewcontroller.m` — transient layouts (including keyboard
  avoidance) are no longer reported as window resizes.
- `SDL_uikitappdelegate.m` — `attemptRotationToDeviceOrientation` runs on
  activation so that UIKit re-synchronises the layout.
- `components/sdlutil/sdlinputwrapper.cpp`, `apps/openmw/engine.cpp` and
  `apps/openmw/mwinput/inputmanagerimp.cpp` — the engine, viewport and UI all
  use the EAGL drawable size on iOS, the camera viewport and projection are
  synced on size changes, and SDL is told the app is landscape-only. Window
  sizes are not persisted as the video resolution on iOS.

These changes are applied by `deps/apply-patches.sh`; see the
`deps/patches/SDL2-2.0.9-src-video-uikit-*.patch` files.

## Performance / renderer tuning

The iOS build renders through GL4ES (desktop GL 2.x to OpenGL ES 2.0) on top of
OpenSceneGraph's GL2 profile, because OpenMW 0.46's scene graph and shader
corpus assume the fixed-function pipeline. The work below was driven by
on-device measurements on the reference device (iPad 3,6 / A6X, PowerVR
SGX 554, iOS 8.4.1, armv7 build against the iOS 7.1 SDK).

### Measuring frame rate

`apps/openmw/engine.cpp` logs a `[perf]` line to `openmw.log` every five
seconds with the achieved frame rate, the average frame time and the current
EAGL drawable size:

```
[perf] fps=21.3118 frame_ms=46.9223 drawable=1024x768
```

Because `debugserver` on iOS 8 refuses extra program arguments, the
`--skip-menu` / `--new-game` switches cannot be passed on the device. They are
therefore also accepted from the environment, so a benchmark can jump straight
into a new game:

```sh
ssh mobile@iPadHelling
# iOS 6 keeps bundles under /var/mobile/Applications/<UUID>/; iOS 8+ moved them
# to $HOME/Containers/Bundle/Application/<UUID>/. Resolve both roots.
OPENMW_SKIP_MENU=1 $HOME/debugserver *:1234 \
  $(find /var/mobile/Applications $HOME/Containers/Bundle/Application -name "OpenMW.app" 2>/dev/null)/openmw
```

### Render resolution: `ios render scale`

On iOS the EAGL drawable is the real render surface and SDL creates it at
`view bounds x contentScaleFactor`, i.e. the full Retina resolution
(2048x1536 on this device). `[Video] resolution x/y` has no effect there.

`[Video] ios render scale` sets the EAGL view's content scale factor instead:

| value | drawable (iPad 4) | notes |
|-------|------------------|-------|
| 2.0 | 2048x1536 | native Retina, the original behaviour |
| 1.0 | 1024x768 | default; one drawable pixel per UIKit point |
| 0.5 | 512x384 | only useful when the GPU is the bottleneck |

The scale is applied in `GraphicsWindowSDL2::init()`, while the freshly created
GLES context is current, because SDL only creates the `CAEAGLLayer`-backed view
inside `SDL_GL_CreateContext`. Touch input is unaffected: SDL converts touches
in UIKit points, and the point size does not change.

Measured in-game frame rates (Seyda Neen, new game, five-second averages, armv7
build on the reference iPad 3,6):

| configuration | fps |
|---------------|-----|
| 2048x1536, default settings | 5.0 - 9.0 |
| 1024x768, default settings | 7.8 - 14.7 |
| 512x384, default settings | 10.1 - 23.3 |
| 1024x768, defaults in this tree | 16.2 - 24.7, steady 18.9 - 19.5 |

The menu renders at the vsync limit (56-60 fps) in every configuration.

512x384 is not faster than 1024x768, and dropping the view distance from 4096
to 3072 (or the terrain LOD factor from 0.7 to 0.5, or the actor processing
range from 2048 to 1024) does not change the result either: the renderer is
**CPU bound at 1x**, and the remaining cost is a fixed per-frame amount, not
the number of visible objects. 30 fps was therefore not reached in gameplay.

### Where the remaining time goes

Sampling the live process with `lldb` while in-game shows the main thread
idle in `osgViewer::ViewerBase::renderingTraversals()` and the work spread over
the cull/draw path: `osgUtil::CullVisitor::createOrReuseRenderLeaf`,
`SceneUtil::LightListCallback::pushLightState` ->
`SceneUtil::LightManager::getLightListStateSet`, `osg::Texture2D::apply`,
`MyGUI::RenderItem::renderToTarget`, plus GL4ES entry points. That is one
thread of OSG cull plus GL4ES translating the desktop-GL state and draw calls
to GLES2 on a dual-core A6X. Further gains need renderer work (merging draw
calls / reducing state changes), not more settings.

One measured improvement came out of this: the per-object light-list ->
`StateSet` cache in `components/sceneutil/lightmanager.hpp` was a
`std::map<size_t, ...>` keyed by a 64-bit hash, consulted for every object on
every frame. It is now a `std::unordered_map`, which removes a red-black-tree
lookup from the cull traversal.

The `[Navigator]` navmesh threads are *not* the bottleneck: they show up in
profiles during cell streaming, but reducing the Recast voxel density
(`cell size` 0.2 -> 0.4) does not raise the frame rate, and
`[Navigator] enable = false` must not be used on this port -- with it the game
falls back to the title screen and never loads a cell.

### Scene cost defaults lowered for iOS

`files/settings-default.cfg` ships with reduced draw cost for armv7 hardware:
`[Camera] viewing distance = 4096`, `[Camera] small feature culling pixel
size = 6.0`, `[Terrain] lod factor = 0.7`, `[Game] actors processing range =
2048`, `[Water] reflection detail = 0`, `[Water] rtt size = 256`,
`[General] anisotropy = 1`. `[Cells] target framerate` stays at 60.

Raising `viewing distance` back towards 6656 restores the full view distance at
roughly half the frame rate. Setting `[Video] ios render scale = 2.0` restores
native Retina rendering at roughly a third of the frame rate.

### GL4ES flags set by the app

`apps/openmw/main.cpp` sets, before any GL call:
`LIBGL_USEVBO=0` (the gl4es VBO conversion path crashed the iOS 8 PowerVR
driver), `LIBGL_NOERROR=1` (skip `glGetError` in hot paths),
`LIBGL_NOBANNER=1`, and `LIBGL_LOGSHADERERROR=1`.

`LIBGL_RECYCLEFBO=1` must NOT be enabled: combined with the port's framebuffer
patch it corrupts gl4es' FBO list and crashes in
`gl4es_glDeleteFramebuffers` during cell loading. `LIBGL_USEVBO=1` was also
tried and is neutral on this hardware.

## Native GLES2 instead of GL4ES

Not done, and not achievable as a drop-in switch. The investigation is recorded
here so it does not have to be repeated.

The C++ side is already close to GLES2 clean: there are no immediate-mode calls
and no matrix queries anywhere in `apps/` or `components/`, only one
`glEnable(GL_DEPTH_CLAMP)` (`apps/openmw/mwrender/water.cpp:420`, not available
in GLES2) and seven `glLight*` calls in
`components/sceneutil/lightmanager.cpp:78-89`.

The real blockers are:

- **The shader corpus.** All ten compilable shaders are `#version 120` with
  fixed-function built-ins: 1094 lines total, using `gl_LightSource` (17x),
  `gl_TextureMatrix` (11x), `gl_FrontMaterial` (9x), `gl_NormalMatrix` (9x),
  `gl_Fog` (9x), `gl_ModelViewMatrixInverse` (7x), `gl_EyePlane*` (4x), plus
  `gl_ClipVertex` and `shadow2DProj`. None of these exist in GLSL ES 1.00;
  GL4ES is what translates them today.
- **The fixed-function state sets.** About 181 `osg::` fixed-function
  references (roughly 120 of them `osg::Material`, then `Fog`, `LightModel`,
  `LightSource`, `AlphaFunc`, `TexEnv`, `PolygonMode`, `ClipPlane`). OSG is
  built with `-DOPENGL_PROFILE=GL2` (`deps/build-osg.sh:7`), which bakes
  `#define OSG_GL_FIXED_FUNCTION_AVAILABLE` into `deps/include/osg/GL:32`.
  Rebuilding OSG for GLES2 undefines that macro, and every one of those state
  sets silently becomes a no-op, so the scene renders unlit.

A native GLES2 port therefore requires rewriting all ~1094 lines of GLSL for
GLSL ES 1.00 and replacing the fixed-function state sets with a
material/light uniform layer fed from `components/shader/shadervisitor.cpp`.
That is a renderer rewrite, not a build flag.

## Installing

```sh
scp packages/org.openmw.ios6_*.ipa mobile@iPadHelling:/var/mobile/
ssh mobile@iPadHelling
appinst /var/mobile/org.openmw.ios6_*.ipa
```

The bundle is installed as `/Applications/OpenMW.app`. Configuration and logs
live in `$HOME/Library/Preferences/OpenMW`; saves and screenshots go to
`$HOME/Documents/OpenMW/{saves,screenshots}`.

Game data can be placed in either of these locations:

- `$HOME/Documents/OpenMW/data/Data Files` inside the app's data container, or
- `/var/mobile/Documents/OpenMW/data/Data Files` for this jailbroken device.
  On startup the app creates a symlink from its container to that directory if
  it exists, so reinstalling the IPA does not require copying 1.2 GB again.

`appinst` creates a fresh data container on every install. The automatic
symlink handles the game data; copied saves in the old container are not
migrated.

### Install troubleshooting

- The application bundle deliberately uses `assets/` instead of `resources/`.
  iOS 8.4.1 `installd` rejects a top-level directory named `resources` with a
  misleading `MissingBundleIdentifier` LaunchServices error.
- `LIBGL_USEVBO=0` is set by the app: the gl4es VBO conversion path crashes the
  iOS 8.4 PowerVR driver in `fpe_glDrawArrays`/`GLEngine`. The client-array
  path renders correctly.

## Debugging

`debugserver` must be present at `$HOME/debugserver` on the device. iOS does not
ship it; copy it from the `DeveloperDiskImage` matching the firmware. The bundle
lives under `/var/mobile/Applications/<UUID>/OpenMW.app` on iOS 6 and under
`$HOME/Containers/Bundle/Application/<UUID>/OpenMW.app` on iOS 8+, so resolve it
with `find` rather than hardcoding the UUID:

```sh
$HOME/debugserver *:1234 \
  $(find /var/mobile/Applications $HOME/Containers/Bundle/Application -name "OpenMW.app" 2>/dev/null)/openmw
```

then on the host:

```sh
lldb
(lldb) process connect connect://iPadHelling:1234
```

Logs from the engine go to `$HOME/Library/Preferences/OpenMW/openmw.log`
inside the application sandbox.
