// SelectedTextResolver.swift — AX fast-path with simulated Cmd+C fallback.
//
// 1. Try AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute)
//    with a 50 ms timeout.
// 2. If empty/missing, save NSPasteboard, post Cmd+C via CGEvent, poll
//    changeCount until it ticks (or 150 ms timeout), read new clipboard,
//    restore original.
//
// Reference: github.com/tisfeng/SelectedTextKit
//
// TODO: implement in Phase 1.

import AppKit
