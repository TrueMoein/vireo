// BusyCard.swift — what the notch shows while a correction is in flight.

import SwiftUI

struct BusyCard: View {
    let label: String

    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Reading and analyzing…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .frame(width: 360, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}
