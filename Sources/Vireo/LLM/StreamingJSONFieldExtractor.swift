// StreamingJSONFieldExtractor.swift — a tiny state machine that extracts
// the value of one top-level string field from a JSON object as it
// streams in chunk-by-chunk.
//
// Used by the streaming OpenRouter adapter to surface the
// `corrected_text` value to the UI as it's being generated, before the
// full JSON object has closed. The full object is still re-parsed at
// the end of the stream for the `mistakes` array.
//
// Design:
//   • Pure-Swift, no Foundation. Easy to unit-test.
//   • Single-field, top-level extraction only. We don't need a full
//     JSON parser — just enough to recognize "field": "..." with
//     proper string-escape handling.
//   • Phase 1: scan for `"<field>"\s*:\s*"`. Phase 2: capture value
//     bytes (handling `\"`, `\\`, `\n`, `\t`, etc.) until the closing
//     unescaped `"` is seen.

import Foundation

struct StreamingJSONFieldExtractor {
    /// The field name we're hunting for (without quotes).
    private let targetField: String

    /// Everything seen so far. We keep it because we need to recognize
    /// the `"field": "` prefix across chunk boundaries.
    private var buffer: String = ""

    /// Parsing phase.
    private enum Phase {
        case scanning            // looking for `"<field>": "` opener
        case capturing           // inside the value, building partial
        case escaped             // last char was `\` inside the value
        case done                // closing `"` consumed
    }
    private var phase: Phase = .scanning

    /// The accumulated value string. Use `current` to read it.
    private var value: String = ""

    init(targetField: String) {
        self.targetField = targetField
    }

    /// Feed one chunk of streamed JSON content. Returns the latest
    /// partial value (or nil if we haven't reached the field yet).
    /// Stops growing once `isComplete == true`.
    mutating func feed(_ chunk: String) -> String? {
        guard phase != .done else { return value }
        buffer += chunk
        switch phase {
        case .scanning:
            tryFindOpener()
            // `tryFindOpener` may flip us into .capturing and consume
            // some buffer; fall through to capture loop on the rest.
            if phase == .capturing {
                consumeValueBytes()
            }
        case .capturing, .escaped:
            consumeValueBytes()
        case .done:
            break
        }
        return phase == .scanning ? nil : value
    }

    var current: String? {
        phase == .scanning ? nil : value
    }

    var isComplete: Bool { phase == .done }

    // MARK: - Internals

    /// Look for the opener `"<field>"\s*:\s*"` in the buffer. If found,
    /// switch to .capturing and drop the consumed prefix from buffer.
    private mutating func tryFindOpener() {
        // Cheap substring scan; field names are short.
        let needle = "\"\(targetField)\""
        guard let nameRange = buffer.range(of: needle) else { return }
        // From after the field name, skip whitespace, expect ":",
        // skip whitespace, expect opening quote.
        var i = nameRange.upperBound
        while i < buffer.endIndex, buffer[i].isWhitespace { i = buffer.index(after: i) }
        guard i < buffer.endIndex, buffer[i] == ":" else { return }
        i = buffer.index(after: i)
        while i < buffer.endIndex, buffer[i].isWhitespace { i = buffer.index(after: i) }
        guard i < buffer.endIndex, buffer[i] == "\"" else { return }
        i = buffer.index(after: i)
        // Anything after this index is value bytes — handle in consumeValueBytes.
        buffer = String(buffer[i...])
        phase = .capturing
    }

    /// Walk the buffer, appending characters to `value` and honoring
    /// JSON escape sequences. Stops on unescaped closing quote.
    private mutating func consumeValueBytes() {
        var consumedUpTo = buffer.startIndex
        var i = buffer.startIndex
        while i < buffer.endIndex {
            let ch = buffer[i]
            switch phase {
            case .escaped:
                // Translate the escape sequence
                switch ch {
                case "\"": value += "\""
                case "\\": value += "\\"
                case "/":  value += "/"
                case "n":  value += "\n"
                case "r":  value += "\r"
                case "t":  value += "\t"
                case "b":  value += "\u{08}"
                case "f":  value += "\u{0C}"
                case "u":
                    // 4-hex-digit unicode escape. Need 4 more chars after this.
                    let after = buffer.index(after: i)
                    if buffer.distance(from: after, to: buffer.endIndex) >= 4 {
                        let hexEnd = buffer.index(after, offsetBy: 4)
                        let hex = buffer[after..<hexEnd]
                        if let scalar = UInt32(hex, radix: 16),
                           let unicode = Unicode.Scalar(scalar) {
                            value.append(Character(unicode))
                        }
                        i = hexEnd
                        phase = .capturing
                        consumedUpTo = i
                        continue
                    } else {
                        // Not enough chars yet — preserve `\u<partial>`
                        // for the next chunk to complete.
                        buffer = "\\u" + String(buffer[after...])
                        return
                    }
                default:
                    // Unknown escape — keep literally.
                    value.append("\\")
                    value.append(ch)
                }
                i = buffer.index(after: i)
                consumedUpTo = i
                phase = .capturing
            case .capturing:
                if ch == "\\" {
                    phase = .escaped
                    i = buffer.index(after: i)
                    consumedUpTo = i
                } else if ch == "\"" {
                    // Closing quote — value complete.
                    phase = .done
                    i = buffer.index(after: i)
                    consumedUpTo = i
                    buffer = String(buffer[consumedUpTo...])
                    return
                } else {
                    value.append(ch)
                    i = buffer.index(after: i)
                    consumedUpTo = i
                }
            case .scanning, .done:
                return
            }
        }
        buffer = String(buffer[consumedUpTo...])
    }
}
