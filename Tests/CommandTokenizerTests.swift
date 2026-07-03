import Foundation
import Testing

/// Verifies `CommandTokenizer` matches common shell quoting/escaping rules.
@Suite("Command tokenizer")
struct CommandTokenizerTests {
    @Test func empty() {
        #expect(CommandTokenizer.tokenize("") == [])
        #expect(CommandTokenizer.tokenize("   ") == [])
    }

    @Test func plainWords() {
        #expect(CommandTokenizer.tokenize("echo hello world") == ["echo", "hello", "world"])
    }

    @Test func multipleSpaces() {
        #expect(CommandTokenizer.tokenize("echo    hello   world") == ["echo", "hello", "world"])
        #expect(CommandTokenizer.tokenize("  echo hello  ") == ["echo", "hello"])
    }

    @Test func singleQuotes() {
        #expect(CommandTokenizer.tokenize("echo 'hello world'") == ["echo", "hello world"])
        #expect(CommandTokenizer.tokenize("'it''s fine'") == ["its fine"])
    }

    @Test func doubleQuotes() {
        #expect(CommandTokenizer.tokenize("echo \"hello world\"") == ["echo", "hello world"])
    }

    @Test func escapedQuotesInsideDoubleQuotes() {
        let input = #"echo "say \"hi\"""#
        #expect(CommandTokenizer.tokenize(input) == ["echo", #"say "hi""#])
    }

    @Test func backslashEscapesOutsideQuotes() {
        #expect(CommandTokenizer.tokenize("foo\\ bar baz") == ["foo bar", "baz"])
    }

    @Test func nestedQuoteTypes() {
        #expect(CommandTokenizer.tokenize("echo 'it has \"double\" quotes'") == ["echo", "it has \"double\" quotes"])
        #expect(CommandTokenizer.tokenize("echo \"it's got a single quote\"") == ["echo", "it's got a single quote"])
    }

    @Test func unterminatedQuote() {
        #expect(CommandTokenizer.tokenize("echo \"unterminated rest of line") == ["echo", "unterminated rest of line"])
        #expect(CommandTokenizer.tokenize("echo 'unterminated rest of line") == ["echo", "unterminated rest of line"])
    }
}
