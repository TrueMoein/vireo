#!/usr/bin/env bash
# run.sh — one-shot: kill any existing Vireo, rebuild Vireo.app, launch it.
#
# Use this instead of Xcode's ⌘R when you want Accessibility to actually
# work. Xcode runs the loose Mach-O from DerivedData whose code-signature
# hash changes on every rebuild, so the AX grant evaporates immediately.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "→ Stopping any running Vireo instance"
pkill -x Vireo 2>/dev/null || true
sleep 0.3

bash scripts/build-app.sh

echo ""
echo "→ Opening Vireo.app"
open Vireo.app

echo ""
echo "✓ Vireo launched from Vireo.app"
echo "  Look for the bird in your menu bar / notch."
