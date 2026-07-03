import Foundation

/// Splits a shell-style command string into argv tokens.
///
/// Supports the common shell quoting rules users expect when typing a
/// `docker run`-style command override:
/// - Whitespace separates tokens.
/// - Single quotes (`'…'`) preserve their contents literally — no escapes.
/// - Double quotes (`"…"`) preserve their contents, but allow `\"` and `\\`
///   as escapes.
/// - A backslash outside of quotes escapes the following character.
/// - An unterminated quote is forgiving: everything from the opening quote
///   to the end of the input becomes part of that token, rather than
///   throwing an error.
enum CommandTokenizer {
    static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var hasCurrent = false

        enum QuoteState { case none, single, double }
        var quote: QuoteState = .none

        var iterator = input.makeIterator()
        while let char = iterator.next() {
            switch quote {
            case .none:
                if char == "'" {
                    quote = .single
                    hasCurrent = true
                } else if char == "\"" {
                    quote = .double
                    hasCurrent = true
                } else if char == "\\" {
                    if let next = iterator.next() {
                        current.append(next)
                    }
                    hasCurrent = true
                } else if char.isWhitespace {
                    if hasCurrent {
                        tokens.append(current)
                        current = ""
                        hasCurrent = false
                    }
                } else {
                    current.append(char)
                    hasCurrent = true
                }
            case .single:
                if char == "'" {
                    quote = .none
                } else {
                    current.append(char)
                }
            case .double:
                if char == "\"" {
                    quote = .none
                } else if char == "\\" {
                    if let next = iterator.next() {
                        if next == "\"" || next == "\\" {
                            current.append(next)
                        } else {
                            current.append(char)
                            current.append(next)
                        }
                    } else {
                        current.append(char)
                    }
                } else {
                    current.append(char)
                }
            }
        }

        if hasCurrent {
            tokens.append(current)
        }

        return tokens
    }
}
