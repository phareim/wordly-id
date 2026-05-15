import Foundation

public enum SlashPalette {
    public struct TriggerMatch: Equatable {
        /// The lowercase trigger word (e.g. "do", "write").
        public let trigger: String
        /// Characters typed by the user after `/<trigger> `, up to the caret.
        public let query: String
        /// Index in the source string where the `/` of the trigger starts.
        /// Used by callers to compute the replacement range when inserting.
        public let triggerStart: Int
    }

    /// Detect whether the caret in `source` sits inside a slash-palette context.
    /// A valid trigger is `/<word> ` where `/` is at a word boundary
    /// (start-of-string or after whitespace), `<word>` is in `schemes`, and a single
    /// space follows. Everything between the space and the caret is the live query.
    public static func detectTrigger(in source: String, caretIndex: Int, schemes: Set<String>) -> TriggerMatch? {
        let chars = Array(source)
        guard caretIndex <= chars.count else { return nil }
        var i = caretIndex - 1
        while i >= 0 {
            if chars[i] == "/" {
                if i == 0 || chars[i-1].isWhitespace {
                    let after = String(chars[(i+1)..<caretIndex])
                    guard let spaceIdx = after.firstIndex(of: " ") else { return nil }
                    let word = String(after[..<spaceIdx]).lowercased()
                    guard schemes.contains(word) else { return nil }
                    let query = String(after[after.index(after: spaceIdx)...])
                    if query.contains("\n") { return nil }
                    return TriggerMatch(trigger: word, query: query, triggerStart: i)
                }
                return nil
            }
            if chars[i].isNewline { return nil }
            i -= 1
        }
        return nil
    }

    /// Compute the reference token that should be inserted when the user selects a result.
    public static func insertion(forSelectedID wordlyID: String, scheme: String) -> String {
        "<\(scheme):\(wordlyID)>"
    }
}
