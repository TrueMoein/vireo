// Date+CompactRelative.swift — short, glanceable relative-time format.
//
// "now" / "1m" / "10m" / "2h" / "3d" / "2w" / "4mo" / "1y"
//
// We don't use SwiftUI's `Text(date, style: .relative)` because it
// renders verbose forms ("1 min, 11 secs ago") that don't fit our
// dense notch popover and history rows. The trade-off is that this
// helper returns a snapshot string — it doesn't auto-tick like the
// SwiftUI style. That's fine for our surfaces:
//   • Notch popover is shown briefly on hover (re-rendered each time).
//   • History list reloads on tab switch.

import Foundation

extension Date {
    func compactRelative(now: Date = .now) -> String {
        let secs = now.timeIntervalSince(self)
        if secs < 60 { return "now" }
        if secs < 3600 { return "\(Int(secs / 60))m" }
        if secs < 86_400 { return "\(Int(secs / 3600))h" }
        if secs < 604_800 { return "\(Int(secs / 86_400))d" }
        if secs < 2_592_000 { return "\(Int(secs / 604_800))w" }
        if secs < 31_536_000 { return "\(Int(secs / 2_592_000))mo" }
        return "\(Int(secs / 31_536_000))y"
    }
}
