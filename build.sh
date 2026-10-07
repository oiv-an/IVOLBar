#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
OUT="${IVOL_BUILD_DIR:-$ROOT/build}"
OUT="${OUT:A}"
APP="$OUT/IVOL Bar.app"
mkdir -p "$APP/Contents/MacOS" "$OUT/modules"
xcrun clang -mmacosx-version-min=27.0 -fobjc-arc -fmodules -c "$ROOT/Sources/Visibility.m" -o "$OUT/Visibility.o"
xcrun swiftc -swift-version 5 -O -module-cache-path "$OUT/modules" -import-objc-header "$ROOT/Sources/Visibility.h" "$ROOT/Sources/main.swift" "$ROOT/Sources/HostedItems.swift" "$OUT/Visibility.o" -framework AppKit -framework ApplicationServices -o "$APP/Contents/MacOS/IVOLBar"
/usr/bin/python3 - "$APP" <<'PY'
import plistlib,sys
from pathlib import Path
p=Path(sys.argv[1])/'Contents/Info.plist'
p.write_bytes(plistlib.dumps({'CFBundleIdentifier':'pro.ivol.bar','CFBundleName':'IVOL Bar','CFBundleDisplayName':'IVOL Bar','CFBundleExecutable':'IVOLBar','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.0','CFBundleVersion':'1','LSUIElement':True,'LSMinimumSystemVersion':'27.0','NSHighResolutionCapable':True,'NSAccessibilityUsageDescription':'Определение расположения значков для скрытия только средней группы.'}))
PY
# Stable local development identity, if present; no security settings are changed.
IDENTITY="${IVOL_SIGN_IDENTITY:--}"
codesign --force --sign "$IDENTITY" --identifier pro.ivol.bar "$APP"
codesign --verify --deep --strict "$APP"
printf '\nBuilt: %s\n' "$APP"
