// MainWindowView.swift — root of the dedicated Vireo window (separate from
// Settings).
//
// Settings (⌘,) is for configuration; this window is for *features* —
// History of your corrections + the Patterns / Coach surface for spaced-
// repetition reviews. Opened from the notch popover's "Open Vireo" entry.

import SwiftUI

struct MainWindowView: View {
    var body: some View {
        TabView {
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            PatternsView()
                .tabItem { Label("Patterns", systemImage: "chart.bar.doc.horizontal") }
        }
        .frame(minWidth: 720, minHeight: 560)
    }
}
