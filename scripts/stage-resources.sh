#!/bin/bash
# Stage OpenMW's runtime resources into Resources/ so Theos copies them into
# the application bundle.  The engine chdirs to the bundle directory on iOS and
# uses ./resources by default.
set -euo pipefail
ROOT="${THEOS_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
OUT="$ROOT/Resources/assets"

rm -rf "$ROOT/Resources"
mkdir -p "$OUT"

cp -R "$ROOT/files/mygui" "$OUT/mygui"
cp -R "$ROOT/files/shaders" "$OUT/shaders"
cp -R "$ROOT/files/vfs" "$OUT/vfs"
cp "$ROOT/files/settings-default.cfg" "$OUT/settings-default.cfg"
cp "$ROOT/files/gamecontrollerdb.txt" "$OUT/gamecontrollerdb.txt"
cp "$ROOT/files/launcher/images/openmw.png" "$OUT/mygui/openmw.png"

# Global configuration: use the full upstream openmw.cfg (it contains all the
# fallback values the engine expects).  The data directory is injected by the
# iOS-specific code in main.cpp, so no token/path with spaces is parsed here.
sed -e '/^data=/d' -e '/^data-local=/d' \
    -e "s|\${OPENMW_RESOURCE_FILES}|./assets|" \
    "$ROOT/files/openmw.cfg" > "$OUT/openmw.cfg"
cat >> "$OUT/openmw.cfg" <<'EOF'
fallback-archive=Morrowind.bsa
fallback-archive=Tribunal.bsa
fallback-archive=Bloodmoon.bsa
content=Morrowind.esm
EOF

printf '0.46.0\n\n\n' > "$OUT/version"

# Minimal iOS 6 Info.plist.  Theos moves Resources/Info.plist to the bundle
# root during staging.
cat > "$ROOT/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleDisplayName</key>
    <string>OpenMW</string>
    <key>CFBundleExecutable</key>
    <string>openmw</string>
    <key>CFBundleIdentifier</key>
    <string>org.openmw.ios6</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenMW</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.46.0</string>
    <key>CFBundleVersion</key>
    <string>0.46.0</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>MinimumOSVersion</key>
    <string>6.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UIRequiresFullScreen</key>
    <true/>
    <key>UIInterfaceOrientation</key>
    <string>UIInterfaceOrientationLandscapeRight</string>
    <key>UIInterfaceOrientation~ipad</key>
    <string>UIInterfaceOrientationLandscapeRight</string>
    <key>UIStatusBarHidden</key>
    <true/>
    <key>UIFileSharingEnabled</key>
    <true/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
PLIST

echo "Staged resources in $OUT"
