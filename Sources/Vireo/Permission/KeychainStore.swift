// KeychainStore.swift — read/write API keys via Keychain Services.
//
// One generic password entry per provider (kSecAttrService = "co.vireo",
// kSecAttrAccount = provider name). Returns nil if not set.
//
// TODO: implement in Phase 1.

import Foundation
import Security
