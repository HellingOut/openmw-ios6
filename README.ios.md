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
- `apps/openmw/mwphysics/heightfield.cpp` — terrain heights are converted to
  `btScalar` before being handed to `btHeightfieldTerrainShape`. Bullet 2.89
  declares that buffer as `const btScalar*`, so with `BT_USE_DOUBLE_PRECISION`
  (which this build uses) it read 8 bytes per vertex out of the game's `float`
  array, stepping over every second height. The resulting collision mesh was
  garbage: the player fell through all terrain, and the degenerate "contacts" it
  produced could throw the actor millions of units away (only the skybox
  visible). Single-precision Bullet, as used by most desktop builds, hides this.
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

`debugserver` is available on the test device:

```sh
$HOME/debugserver *:1234 $HOME/Containers/Bundle/Application/*/OpenMW.app/openmw
```

then on the host:

```sh
lldb
(lldb) process connect connect://iPadHelling:1234
```

Logs from the engine go to `$HOME/Library/Preferences/OpenMW/openmw.log`
inside the application sandbox.
