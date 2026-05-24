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
                    .font(.Vireo.statusLine.bold())
                    .foregroundStyle(.primary)
                if let detail = message.detail {
                    Text(detail)
                        .font(.Vireo.detail)
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
        .vireoGlassCard(cornerRadius: 18)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var toneColor: Color {
        switch message.tone {
        case .info: return Color.Vireo.info
        case .warning: return Color.Vireo.warning
        case .error: return Color.Vireo.mistake
        }
    }
}
