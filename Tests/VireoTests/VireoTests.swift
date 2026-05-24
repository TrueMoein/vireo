// VireoTests.swift — small targeted unit tests for the pure-logic
// helpers. UI / IO components are exercised by running the app.

import XCTest
@testable import Vireo

final class SentenceDiffTests: XCTestCase {
    func testIdenticalInputProducesAllSame() {
        let tokens = SentenceDiff.compute(
            original: "the quick brown fox",
            corrected: "the quick brown fox"
        )
        XCTAssertEqual(tokens, [
            .same("the"),
            .same("quick"),
            .same("brown"),
            .same("fox"),
        ])
    }

    func testInsertion() {
        let tokens = SentenceDiff.compute(
            original: "I want create feature",
            corrected: "I want to create a feature"
        )
        XCTAssertEqual(tokens, [
            .same("I"),
            .same("want"),
            .inserted("to"),
            .same("create"),
            .inserted("a"),
            .same("feature"),
        ])
    }

    func testDeletion() {
        let tokens = SentenceDiff.compute(
            original: "I really really want this",
            corrected: "I really want this"
        )
        // Either "really" could be deleted (LCS is ambiguous on
        // duplicate tokens). What matters: exactly one is deleted, and
        // walking the same+inserted tokens reproduces the corrected
        // sentence.
        let deletions = tokens.filter { if case .deleted = $0 { return true } else { return false } }
        XCTAssertEqual(deletions.count, 1)
        let reconstructed = tokens.compactMap { token -> String? in
            switch token {
            case .same(let w), .inserted(let w): return w
            case .deleted: return nil
            }
        }.joined(separator: " ")
        XCTAssertEqual(reconstructed, "I really want this")
    }

    func testReplacement() {
        let tokens = SentenceDiff.compute(
            original: "he go home",
            corrected: "he goes home"
        )
        XCTAssertEqual(tokens, [
            .same("he"),
            .deleted("go"),
            .inserted("goes"),
            .same("home"),
        ])
    }
}

final class StreamingJSONFieldExtractorTests: XCTestCase {
    func testExtractsCompleteValue() {
        var ex = StreamingJSONFieldExtractor(targetField: "corrected_text")
        let partial = ex.feed(#"{"corrected_text": "hello world", "mistakes": []}"#)
        XCTAssertEqual(partial, "hello world")
        XCTAssertTrue(ex.isComplete)
    }

    func testExtractsAcrossChunkBoundaries() {
        var ex = StreamingJSONFieldExtractor(targetField: "corrected_text")
        XCTAssertNil(ex.feed("{\"corre"))
        XCTAssertNil(ex.feed("cted_text\""))
        XCTAssertEqual(ex.feed(": \"hel"), "hel")
        XCTAssertEqual(ex.feed("lo "), "hello ")
        XCTAssertEqual(ex.feed("world\", "), "hello world")
        XCTAssertTrue(ex.isComplete)
    }

    func testHandlesEscapedQuote() {
        var ex = StreamingJSONFieldExtractor(targetField: "corrected_text")
        let partial = ex.feed(#"{"corrected_text":"she said \"hi\""}"#)
        XCTAssertEqual(partial, #"she said "hi""#)
        XCTAssertTrue(ex.isComplete)
    }

    func testHandlesEscapedNewline() {
        var ex = StreamingJSONFieldExtractor(targetField: "corrected_text")
        let partial = ex.feed(#"{"corrected_text":"line one\nline two"}"#)
        XCTAssertEqual(partial, "line one\nline two")
        XCTAssertTrue(ex.isComplete)
    }

    func testUnicodeEscape() {
        var ex = StreamingJSONFieldExtractor(targetField: "corrected_text")
        // “ = left double quote, ” = right double quote
        let partial = ex.feed(#"{"corrected_text":"“quoted”"}"#)
        XCTAssertEqual(partial, "\u{201C}quoted\u{201D}")
        XCTAssertTrue(ex.isComplete)
    }

    func testIgnoresOtherFields() {
        var ex = StreamingJSONFieldExtractor(targetField: "corrected_text")
        XCTAssertNil(ex.feed(#"{"mistakes":[],"#))
        XCTAssertEqual(ex.feed(#""corrected_text":"yep"}"#), "yep")
        XCTAssertTrue(ex.isComplete)
    }
}

final class ClipboardMonitorFilterTests: XCTestCase {
    func testAcceptsPlainEnglishSentence() {
        XCTAssertTrue(ClipboardMonitor.passesFilter(
            "I really need to update the deployment script before the team meeting."
        ))
    }

    func testRejectsTooShort() {
        XCTAssertFalse(ClipboardMonitor.passesFilter("hi"))
    }

    func testRejectsTooLong() {
        let huge = String(repeating: "a very long sentence that goes on and on. ", count: 200)
        XCTAssertFalse(ClipboardMonitor.passesFilter(huge))
    }

    func testRejectsAllUppercase() {
        XCTAssertFalse(ClipboardMonitor.passesFilter("HELLO THIS IS A SHOUTY HEADER"))
    }

    func testRejectsURL() {
        XCTAssertFalse(ClipboardMonitor.passesFilter("https://example.com/very/long/path?with=params"))
    }

    func testRejectsCodeBlock() {
        XCTAssertFalse(ClipboardMonitor.passesFilter("""
        function add(a, b) {
            return a + b;
        }
        """))
    }

    func testRejectsSingleWord() {
        XCTAssertFalse(ClipboardMonitor.passesFilter("hello"))
    }
}
