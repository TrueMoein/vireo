// ClipboardMonitor.swift — filtered NSPasteboard watcher.
//
// Tertiary capture surface. Polls NSPasteboard.changeCount, filters with the
// sentence heuristic + NLLanguageRecognizer, surfaces a gentle notch pulse
// on match. Default off; auto-suggest opt-in after 3 days of use.
//
// Filter rules:
//   • length 12 – 2000 chars
//   • has lowercase + spaces
//   • doesn't start with http, /, {, <, function, class, import
//   • punctuation density < 0.25
//   • NLLanguageRecognizer detects English with confidence > 0.85
//   • not in last-5 clipboard items
//
// TODO: implement in Phase 6.

import Foundation
import NaturalLanguage
