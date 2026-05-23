// NotchPresenter.swift — wraps DynamicNotchKit, owns the pill↔card state machine.
//
// States: hidden, expandedCard (after correction arrives), collapsedPill
// (after auto-collapse), pinnedCard (user clicked pill to keep open).
// Auto-collapse: card → pill after 4 s, pill → hidden after 12 s, unless
// pinned.
//
// TODO: implement in Phase 1.

import Foundation
