import Foundation

 
 
 
 
 
public enum ConfigurationSourceHighlight {
    public enum Kind: Equatable, Sendable {
        case key
        case string
         
        case literal
        case comment
         
        case punctuation
    }

    public struct Token: Equatable, Sendable {
        public let range: NSRange
        public let kind: Kind
    }

    public static func tokens(in line: String) -> [Token] {
        var reader = LineReader(Array(line.utf16))
        reader.readLine()
        return reader.tokens
    }
}

private struct LineReader {
    let units: [UInt16]
    var tokens: [ConfigurationSourceHighlight.Token] = []
    var index = 0

    init(_ units: [UInt16]) { self.units = units }

    private static let space: UInt16 = 0x20, hash: UInt16 = 0x23, dash: UInt16 = 0x2D, colon: UInt16 = 0x3A
    private static let comma: UInt16 = 0x2C, quote: UInt16 = 0x22, apostrophe: UInt16 = 0x27
    private static let openBrace: UInt16 = 0x7B, closeBrace: UInt16 = 0x7D
    private static let openBracket: UInt16 = 0x5B, closeBracket: UInt16 = 0x5D

    mutating func readLine() {
        skipSpaces()
        while index < units.count, units[index] == Self.dash,
              index + 1 == units.count || units[index + 1] == Self.space {
            emit(index, index + 1, .punctuation)
            index += 1
            skipSpaces()
        }
        guard index < units.count else { return }
        if units[index] == Self.hash { emit(index, units.count, .comment); return }
        if let keyEnd = blockKeyEnd(from: index) {
            emitTrimmed(index, keyEnd, .key)
            index = keyEnd + 1
            skipSpaces()
        }
        readValue()
    }

     
     
    private func blockKeyEnd(from start: Int) -> Int? {
        var cursor = start
        if units[cursor] == Self.quote || units[cursor] == Self.apostrophe {
            guard let close = closingQuote(from: cursor) else { return nil }
            cursor = close + 1
            return cursor < units.count && units[cursor] == Self.colon && isBreak(after: cursor) ? cursor : nil
        }
        if units[cursor] == Self.openBrace || units[cursor] == Self.openBracket { return nil }
        while cursor < units.count {
            if units[cursor] == Self.colon, isBreak(after: cursor) { return cursor }
            if units[cursor] == Self.space, cursor + 1 < units.count, units[cursor + 1] == Self.hash { return nil }
            cursor += 1
        }
        return nil
    }

    private mutating func readValue() {
        guard index < units.count else { return }
        let unit = units[index]
        if unit == Self.hash { emit(index, units.count, .comment); return }
        if unit == Self.openBrace || unit == Self.openBracket {
            readFlow()
        } else if unit == Self.quote || unit == Self.apostrophe {
            let close = closingQuote(from: index) ?? units.count - 1
            emit(index, close + 1, .string)
            index = close + 1
        } else {
            var end = index
            while end < units.count, !(units[end] == Self.space && end + 1 < units.count && units[end + 1] == Self.hash) {
                end += 1
            }
            emitScalar(index, end)
            index = end
        }
        skipSpaces()
        if index < units.count, units[index] == Self.hash { emit(index, units.count, .comment) }
    }

     
     
    private mutating func readFlow() {
        while index < units.count {
            let unit = units[index]
            if unit == Self.openBrace || unit == Self.closeBrace || unit == Self.openBracket
                || unit == Self.closeBracket || unit == Self.comma {
                emit(index, index + 1, .punctuation)
                index += 1
                continue
            }
            if unit == Self.space { index += 1; continue }
            if unit == Self.hash { emit(index, units.count, .comment); index = units.count; return }
            if unit == Self.quote || unit == Self.apostrophe {
                let close = closingQuote(from: index) ?? units.count - 1
                let kind: ConfigurationSourceHighlight.Kind =
                    close + 1 < units.count && units[close + 1] == Self.colon ? .key : .string
                emit(index, close + 1, kind)
                index = close + 1
                if index < units.count, units[index] == Self.colon { index += 1 }
                continue
            }
            var end = index
            while end < units.count {
                let next = units[end]
                if next == Self.comma || next == Self.closeBrace || next == Self.closeBracket
                    || next == Self.openBrace || next == Self.openBracket { break }
                if next == Self.colon, isBreak(after: end) { break }
                end += 1
            }
            if end < units.count, units[end] == Self.colon {
                emitTrimmed(index, end, .key)
                index = end + 1
            } else {
                emitScalar(index, end)
                index = end
            }
        }
    }

    private func isBreak(after colon: Int) -> Bool {
        colon + 1 == units.count || units[colon + 1] == Self.space
    }

    private func closingQuote(from open: Int) -> Int? {
        let mark = units[open]
        var cursor = open + 1
        while cursor < units.count {
            if units[cursor] == mark {
                if mark == Self.apostrophe, cursor + 1 < units.count, units[cursor + 1] == Self.apostrophe {
                    cursor += 2
                    continue
                }
                return cursor
            }
            if mark == Self.quote, units[cursor] == 0x5C { cursor += 2; continue }
            cursor += 1
        }
        return nil
    }

    private mutating func skipSpaces() {
        while index < units.count, units[index] == Self.space { index += 1 }
    }

    private mutating func emitScalar(_ start: Int, _ end: Int) {
        var trimmed = end
        while trimmed > start, units[trimmed - 1] == Self.space { trimmed -= 1 }
        guard trimmed > start else { return }
        let text = String(decoding: units[start..<trimmed], as: UTF16.self)
        emit(start, trimmed, Self.isLiteral(text) ? .literal : .string)
    }

    private mutating func emitTrimmed(_ start: Int, _ end: Int, _ kind: ConfigurationSourceHighlight.Kind) {
        var first = start
        var last = end
        while first < last, units[first] == Self.space { first += 1 }
        while last > first, units[last - 1] == Self.space { last -= 1 }
        emit(first, last, kind)
    }

    private mutating func emit(_ start: Int, _ end: Int, _ kind: ConfigurationSourceHighlight.Kind) {
        let upper = min(end, units.count)
        guard upper > start else { return }
        tokens.append(.init(range: NSRange(location: start, length: upper - start), kind: kind))
    }

    private static func isLiteral(_ text: String) -> Bool {
        switch text.lowercased() {
        case "true", "false", "null", "~": return true
        default: break
        }
        var digits = text[...]
        if digits.first == "-" || digits.first == "+" { digits = digits.dropFirst() }
        if digits.hasPrefix("0x") { return digits.count > 2 && digits.dropFirst(2).allSatisfy(\.isHexDigit) }
        var sawDigit = false
        var sawDot = false
        for character in digits {
            if character.isASCII, character.isNumber { sawDigit = true }
            else if character == ".", !sawDot { sawDot = true }
            else { return false }
        }
        return sawDigit
    }
}
