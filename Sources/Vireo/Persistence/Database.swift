// Database.swift — GRDB connection pool + migrations + FTS5 setup.
//
// Initial schema:
//   sessions(id, timestamp, source_app, raw_text, corrected_text,
//            llm_provider, model, latency_ms)
//   mistakes(id, session_id, original_phrase, corrected_phrase,
//            category, rule, severity)
//   categories(id, name, l1_interference_for_languages)
//   weakness_items(category_id, rule, fsrs_state, due_at, mastered_at?)
//
// FTS5 virtual table mirrors sessions.corrected_text for History search.
// Threading: DatabasePool, all writes inside transactions.
//
// TODO: implement in Phase 4.

import Foundation
