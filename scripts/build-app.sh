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
# Re-grant note: ad-hoc signing (used here when no "Vireo Dev" code-signing
# identity is in Keychain) produces a different signature on each build,
# which can still invalidate AX trust on rebuild. To get sticky trust:
#   1. Open Keychain Access → Keychain Access menu → Certificate Assistant
#      → Create a Certificate
#   2. Name: "Vireo Dev"  ·  Identity Type: Self Signed Root
#      Certificate Type: Code Signing
#   3. After it appears in Keychain, re-run this script — it'll auto-pick
#      the "Vireo Dev" identity and the signature stays stable across builds.

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

# Prefer a stable self-signed identity if the user created one; fall back
# to ad-hoc which works but invalidates trust on each rebuild.
if security find-identity -v -p codesigning 2>/dev/null | grep -q '"Vireo Dev"'; then
    SIGN_IDENTITY="Vireo Dev"
    echo "→ Signing with \"Vireo Dev\" identity (trust persists across builds)"
else
    SIGN_IDENTITY="-"
    echo "→ Ad-hoc signing (trust may need re-granting after rebuild — see top of script)"
fi
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE" 2>&1 | sed 's/^/   /' || true

echo ""
echo "✓ ${APP_BUNDLE}"
echo "  Bundle ID:   ${BUNDLE_ID}"
echo "  Path:        ${APP_BUNDLE}"
echo ""
echo "Run with:    open '${APP_BUNDLE}'"
echo "Or in shell: open Vireo.app   (from project root)"
