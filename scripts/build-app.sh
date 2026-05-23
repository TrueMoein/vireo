#!/usr/bin/env bash
# build-app.sh — wrap the swift-build artifact in a proper Vireo.app bundle.
#
# Why: macOS tracks Accessibility / Input Monitoring grants per binary's
# code-signature hash. Xcode's "Run Package" and `swift run` both produce
# a loose Mach-O whose content changes on every rebuild, so the AX grant
# evaporates each time. Wrapping the binary in a stable .app at the project
# root gives us a real bundle ID (co.vireo), a stable path, and a proper
# Vireo entry in System Settings → Privacy → Accessibility.
#
# Usage:
#   bash scripts/build-app.sh              # debug build (default)
#   bash scripts/build-app.sh release      # release build
#   open Vireo.app                         # run it
#
# Re-grant note: on modern macOS, ad-hoc and self-signed signatures both
# invalidate Accessibility trust whenever the binary's content changes
# (TCC trusts by team identifier, which only exists in real Developer ID
# signatures). That means **every source change requires re-granting AX**.
# Workflows that minimize re-granting:
#   • Don't rebuild between testing sessions if you can avoid it.
#   • A bit-identical rebuild (no source change) produces an identical
#     ad-hoc signature, so trust holds.
#   • For permanent sticky trust, ship with a real Apple Developer ID
#     ($99/yr) — that's Phase 7.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Vireo"
APP_BUNDLE="${PROJECT_ROOT}/${APP_NAME}.app"
BUNDLE_ID="co.vireo"
BUNDLE_VERSION="0.1.0"
CONFIG="${1:-debug}"

cd "$PROJECT_ROOT"

echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG"

ARCH="$(uname -m)"
BIN_PATH=".build/${ARCH}-apple-macosx/${CONFIG}/${APP_NAME}"

if [[ ! -f "$BIN_PATH" ]]; then
    echo "✗ Binary not found at $BIN_PATH"
    exit 1
fi

echo "→ Wrapping in ${APP_NAME}.app"
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
cp "$BIN_PATH" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

BUILD_DIR=".build/${ARCH}-apple-macosx/${CONFIG}"

# Copy frameworks (Sparkle, etc.) and SPM resource bundles (GRDB,
# KeyboardShortcuts) next to the binary. The binary's only LC_RPATH is
# @loader_path, so anything it links against must live alongside it.
shopt -s nullglob
for fwk in "$BUILD_DIR"/*.framework; do
    cp -R "$fwk" "${APP_BUNDLE}/Contents/MacOS/"
    echo "   + $(basename "$fwk")"
done
for bnd in "$BUILD_DIR"/*.bundle; do
    cp -R "$bnd" "${APP_BUNDLE}/Contents/MacOS/"
    echo "   + $(basename "$bnd")"
done
shopt -u nullglob

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/propertylist-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleShortVersionString</key>
    <string>${BUNDLE_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUNDLE_VERSION}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Vireo reads selected text and simulates ⌘C/⌘V to capture and replace it.</string>
</dict>
</plist>
PLIST

# Ad-hoc sign with a stable identifier. The identifier is stable across
# builds (always "co.vireo") even though the content hash isn't, so at least
# the bundle identity reads consistently in Console and System Settings.
codesign --force --deep --sign - \
    --identifier "co.vireo" \
    "$APP_BUNDLE" 2>&1 | sed 's/^/   /' || true

echo ""
echo "✓ ${APP_BUNDLE}"
echo "  Bundle ID:   ${BUNDLE_ID}"
echo "  Path:        ${APP_BUNDLE}"
echo ""
echo "Run with:    open '${APP_BUNDLE}'"
echo "Or in shell: open Vireo.app   (from project root)"
