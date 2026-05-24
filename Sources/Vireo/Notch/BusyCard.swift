// BusyCard.swift — what the notch shows while a correction is in flight.

import SwiftUI

struct BusyCard: View {
    let label: String

    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.small)
                .tint(Color.Vireo.correction)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.Vireo.statusLine)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Reading and analyzing…")
                    .font(.Vireo.categoryChip)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .frame(width: 360, alignment: .leading)
        .vireoGlassCard(cornerRadius: 18)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}
