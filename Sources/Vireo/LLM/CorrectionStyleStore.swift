// CorrectionStyleStore.swift — owns the user's selection of active style
// and any custom styles they've authored.
//
// Built-in styles always come from code (`CorrectionStyle.builtIns`); the
// store only persists the active-style pointer and the user's custom
// styles. This means built-ins can never get out of sync if we update
// their prompts across versions.

import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "co.vireo", category: "StyleStore")

@MainActor
final class CorrectionStyleStore: ObservableObject {
    @Published private(set) var customStyles: [CorrectionStyle] = []
    @Published var activeStyleID: UUID {
        didSet { persistActiveStyleID() }
    }

    static let activeStyleDefaultsKey = "co.vireo.activeStyleID"
    static let customStylesDefaultsKey = "co.vireo.customStyles"

    init() {
        self.activeStyleID = Self.loadActiveStyleID()
        self.customStyles = Self.loadCustomStyles()
    }

    /// All styles available to the user, built-ins first.
    var allStyles: [CorrectionStyle] {
        CorrectionStyle.builtIns + customStyles
    }

    /// Look up a style by ID, falling back to Grammar Coach if missing.
    /// Used by the correction pipeline so an unknown / deleted ID never
    /// breaks the flow.
    func resolve(id: UUID) -> CorrectionStyle {
        allStyles.first(where: { $0.id == id }) ?? CorrectionStyle.grammarCoach
    }

    var activeStyle: CorrectionStyle {
        resolve(id: activeStyleID)
    }

    func setActive(_ id: UUID) {
        guard allStyles.contains(where: { $0.id == id }) else { return }
        activeStyleID = id
    }

    /// Insert a new custom style. Caller already constructed the
    /// `CorrectionStyle` (assign a fresh UUID, set `isBuiltIn = false`).
    func add(_ style: CorrectionStyle) {
        var s = style
        s.isBuiltIn = false
        customStyles.append(s)
        persistCustomStyles()
    }

    /// Update an existing custom style in place. Built-ins are read-only —
    /// caller should not pass a built-in id, but we guard regardless.
    func update(_ style: CorrectionStyle) {
        guard let idx = customStyles.firstIndex(where: { $0.id == style.id }) else {
            log.error("update: style \(style.id, privacy: .public) not in custom list")
            return
        }
        var s = style
        s.isBuiltIn = false
        customStyles[idx] = s
        persistCustomStyles()
    }

    /// Delete a custom style. Built-ins are protected. If the deleted
    /// style was active, fall back to Grammar Coach.
    func delete(id: UUID) {
        guard let style = customStyles.first(where: { $0.id == id }) else { return }
        guard !style.isBuiltIn else { return }
        customStyles.removeAll { $0.id == id }
        if activeStyleID == id {
            activeStyleID = CorrectionStyle.grammarCoachID
        }
        persistCustomStyles()
    }

    /// Make a custom copy of an existing style (built-in or custom) and
    /// return the new style so the caller can open the editor on it.
    func duplicate(_ style: CorrectionStyle) -> CorrectionStyle {
        let copy = CorrectionStyle(
            id: UUID(),
            name: "Copy of \(style.name)",
            subtitle: style.subtitle,
            icon: style.icon,
            systemPrompt: style.systemPrompt,
            isBuiltIn: false
        )
        customStyles.append(copy)
        persistCustomStyles()
        return copy
    }

    // MARK: - Persistence

    private func persistActiveStyleID() {
        UserDefaults.standard.set(activeStyleID.uuidString, forKey: Self.activeStyleDefaultsKey)
    }

    private func persistCustomStyles() {
        do {
            let data = try JSONEncoder().encode(customStyles)
            UserDefaults.standard.set(data, forKey: Self.customStylesDefaultsKey)
        } catch {
            log.error("persistCustomStyles: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func loadActiveStyleID() -> UUID {
        guard let raw = UserDefaults.standard.string(forKey: activeStyleDefaultsKey),
              let id = UUID(uuidString: raw) else {
            return CorrectionStyle.grammarCoachID
        }
        return id
    }

    private static func loadCustomStyles() -> [CorrectionStyle] {
        guard let data = UserDefaults.standard.data(forKey: customStylesDefaultsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([CorrectionStyle].self, from: data)
        } catch {
            log.error("loadCustomStyles: \(error.localizedDescription, privacy: .public) — starting empty")
            return []
        }
    }
}
