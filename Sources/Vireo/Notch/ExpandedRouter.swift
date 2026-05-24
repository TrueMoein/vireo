// ExpandedRouter.swift — switches the notch's expanded content based on
// NotchModel.display.

import SwiftUI

struct ExpandedRouter: View {
    @ObservedObject var model: NotchModel
    let presenter: NotchPresenter

    var body: some View {
        Group {
            switch model.display {
            case .idle:
                Color.clear.frame(width: 1, height: 1)
            case .popover:
                if let store = presenter.sessionStore,
                   let perm = presenter.permission,
                   let styles = presenter.styleStore {
                    NotchPopover(
                        settings: presenter.settings,
                        sessionStore: store,
                        permission: perm,
                        styleStore: styles,
                        presenter: presenter
                    )
                    .transition(.blurReplace.combined(with: .scale(0.96)))
                } else {
                    NotchPopover(
                        settings: presenter.settings,
                        sessionStore: SessionStore(repository: nil),
                        permission: AccessibilityPermission(),
                        styleStore: CorrectionStyleStore(),
                        presenter: presenter
                    )
                    .transition(.blurReplace.combined(with: .scale(0.96)))
                }
            case .correction(let result):
                CorrectionCard(
                    result: result,
                    styleStore: presenter.coordinator?.styleStore,
                    onReplace: { [weak presenter] in
                        Task { @MainActor in
                            // Coordinator surfaces a "Replaced into X" toast
                            // that auto-hides; no manual dismiss here.
                            await presenter?.coordinator?.replaceCorrection(result.correctedText)
                        }
                    },
                    onCopy: { [weak presenter] in
                        presenter?.coordinator?.copyCorrection(result.correctedText)
                    },
                    onDismiss: { [weak presenter] in
                        Task { @MainActor in await presenter?.dismissToIdle() }
                    },
                    onRecorrect: { [weak presenter] newStyleID in
                        Task { @MainActor in
                            await presenter?.coordinator?.correct(
                                text: result.originalText.isEmpty
                                    ? result.correctedText
                                    : result.originalText,
                                styleID: newStyleID
                            )
                        }
                    }
                )
                .transition(.blurReplace.combined(with: .scale(0.96)))
            case .busy(let label):
                BusyCard(label: label)
                    .transition(.blurReplace.combined(with: .scale(0.96)))
            case .message(let message):
                MessageCard(message: message)
                    .transition(.blurReplace.combined(with: .scale(0.96)))
            case .firstLaunch:
                FirstLaunchCard()
                    .transition(.blurReplace.combined(with: .scale(0.94)))
            case .streamingCorrection(let partial):
                StreamingCorrectionCard(
                    partial: partial,
                    onCancel: { [weak presenter] in
                        Task { @MainActor in
                            presenter?.coordinator?.cancelInflightCorrection()
                            await presenter?.dismissToIdle()
                        }
                    }
                )
                .transition(.blurReplace.combined(with: .scale(0.96)))
            case .review(let payload):
                if let drillGenerator = presenter.coordinator?.drillGenerator {
                    NotchReviewCard(
                        payload: payload,
                        drillGenerator: drillGenerator,
                        onRate: { [weak presenter] grade in
                            Task { @MainActor in
                                await presenter?.rateReview(payload: payload, grade: grade)
                            }
                        },
                        onDismiss: { [weak presenter] in
                            Task { @MainActor in
                                await presenter?.dismissReview()
                            }
                        }
                    )
                    .transition(.blurReplace.combined(with: .scale(0.96)))
                } else {
                    Text("Drill unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(.Vireo.entry, value: displayKey)
    }

    private var displayKey: String {
        switch model.display {
        case .idle: return "idle"
        case .popover: return "popover"
        case .correction: return "correction"
        case .busy: return "busy"
        case .message: return "message"
        case .firstLaunch: return "firstLaunch"
        case .review(let p): return "review-\(p.item.id ?? 0)"
        // Keep the same key while streaming so SwiftUI doesn't tear
        // down + recreate the card on every partial-text update.
        case .streamingCorrection: return "streamingCorrection"
        }
    }
}
