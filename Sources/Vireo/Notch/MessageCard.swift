// MessageCard.swift — transient info/warning/error feedback for the notch.

import SwiftUI

struct MessageCard: View {
    let message: NotchMessage

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: message.icon)
                .font(.title3)
                .foregroundStyle(toneColor)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(message.title)
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                if let detail = message.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 440, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var toneColor: Color {
        switch message.tone {
        case .info: return .blue
        case .warning: return Color(red: 0.85, green: 0.55, blue: 0.20)
        case .error: return Color(red: 0.851, green: 0.467, blue: 0.341)
        }
    }
}
