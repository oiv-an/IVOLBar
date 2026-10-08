#!/bin/zsh
# Build and package a local arm64 release. Does not install, launch or upload.
set -euo pipefail
ROOT="${0:A:h:h}"
if [[ "$(uname -m)" != "arm64" ]]; then
  print -u2 'Release packaging currently supports Apple Silicon (arm64) only.'
  exit 1
fi
mkdir -p "$ROOT/dist"
WORK="$(mktemp -d "$ROOT/dist/.package.XXXXXX")"
print "Working directory: $WORK"
# Never export a maintainer's local signing certificate in the public artifact.
IVOL_BUILD_DIR="$WORK/build" IVOL_SIGN_IDENTITY='-' /bin/zsh "$ROOT/build.sh"
APP="$WORK/build/IVOL Bar.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 "Unexpected release version: $VERSION"
  exit 1
fi
if [[ "$(lipo -archs "$APP/Contents/MacOS/IVOLBar")" != 'arm64' ]]; then
  print -u2 'Refusing to label a non-arm64 binary as an arm64 release.'
  exit 1
fi
DEST="$ROOT/dist/$VERSION"
ARCHIVE="IVOL-Bar-$VERSION-macos-arm64.zip"
if [[ -e "$DEST/$ARCHIVE" || -e "$DEST/SHA256SUMS.txt" ]]; then
  print -u2 "Release output already exists in $DEST; preserve it before rebuilding."
  exit 1
fi
mkdir -p "$WORK/archive" "$DEST"
ditto --noextattr --norsrc "$APP" "$WORK/archive/IVOL Bar.app"
cp "$ROOT/LICENSE" "$WORK/archive/LICENSE"
cat > "$WORK/archive/INSTALL.txt" <<'TXT'
IVOL Bar — experimental macOS 27 menu bar utility

Apple Silicon (arm64). Tested on macOS 27.0.1.
Ad-hoc signed. NOT Developer ID signed or notarized by Apple.

Move IVOL Bar.app to Applications, then open it. If macOS blocks the first
launch, review System Settings > Privacy & Security > Open Anyway, only if
you trust this download. Do not disable Gatekeeper globally.
Grant Accessibility access when prompted. Open the divider/right-click menu,
choose "Настроить группу по расположению…", then Command-drag the divider
to the left of the arrow and place the icons to hide between them. Choose
"Сохранить группу по расположению" to save. Membership persists independently
of display geometry; dragging outside configuration mode does not change it.
Auto-hide is OFF in a new profile; enable it from the divider/right-click menu.
Quit the old IVOL Bar before replacing an existing installation.

English: https://github.com/oiv-an/IVOLBar#readme
Русский: https://github.com/oiv-an/IVOLBar/blob/main/README.ru.md
Source and issues: https://github.com/oiv-an/IVOLBar
License: MIT (included). Private Apple APIs may break in future macOS updates.
TXT
codesign --verify --deep --strict "$WORK/archive/IVOL Bar.app"
ditto -c -k --norsrc --noextattr "$WORK/archive" "$DEST/$ARCHIVE"
/usr/bin/python3 - "$DEST/$ARCHIVE" "$DEST/SHA256SUMS.txt" <<'PY'
import hashlib
import sys
from pathlib import Path
archive = Path(sys.argv[1])
Path(sys.argv[2]).write_text(f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n')
PY
print "\nRelease archive: $DEST/$ARCHIVE"
print "Checksum: $DEST/SHA256SUMS.txt"
print 'Not installed or uploaded. Temporary build kept for inspection.'
