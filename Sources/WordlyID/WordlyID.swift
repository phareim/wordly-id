import Foundation

public enum WordlyID {
    /// Generate a new identifier of the form `<PREFIX>-<WORD>-<WORD>-<WORD>`.
    /// Words are drawn one each from the noun, adjective, and verb partitions.
    public static func generate(prefix: String) -> String {
        let wordlist = try! cachedWordlist()
        let noun = wordlist.nouns.randomElement()!.uppercased()
        let adjective = wordlist.adjectives.randomElement()!.uppercased()
        let verb = wordlist.verbs.randomElement()!.uppercased()
        return "\(prefix)-\(noun)-\(adjective)-\(verb)"
    }

    /// Generate a unique identifier. The `isUnique` callback is invoked with each
    /// candidate; the first that returns `true` is returned. After 3 rejections,
    /// the generator falls back to appending `-2`, `-3`, … to the most recent draw
    /// until a candidate is accepted.
    public static func generate(prefix: String, isUnique: (String) -> Bool) -> String {
        var lastDraw: String = ""
        for _ in 0..<3 {
            let candidate = generate(prefix: prefix)
            lastDraw = candidate
            if isUnique(candidate) { return candidate }
        }
        var suffix = 2
        while true {
            let candidate = "\(lastDraw)-\(suffix)"
            if isUnique(candidate) { return candidate }
            suffix += 1
            if suffix > 1000 {
                // Astronomically improbable; fall back to a UUID-tagged form so we never loop forever.
                return "\(lastDraw)-\(UUID().uuidString.prefix(8))"
            }
        }
    }

    /// Decompose a WordlyID into its prefix and words. Returns nil if the input
    /// is not a syntactically valid WordlyID.
    public static func parse(_ id: String) -> (prefix: String, words: [String])? {
        guard !id.isEmpty else { return nil }
        let segments = id.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        // Need a prefix + at least 3 words.
        guard segments.count >= 4 else { return nil }
        // Every segment non-empty and uppercase-letters-or-digits (digits for suffix fallback).
        for segment in segments {
            guard !segment.isEmpty else { return nil }
            for scalar in segment.unicodeScalars {
                let isUppercaseLetter = (0x41...0x5A).contains(scalar.value)
                let isDigit = (0x30...0x39).contains(scalar.value)
                guard isUppercaseLetter || isDigit else { return nil }
            }
        }
        return (segments[0], Array(segments.dropFirst()))
    }

    /// True iff `id` is a syntactically valid WordlyID.
    public static func validate(_ id: String) -> Bool {
        parse(id) != nil
    }

    // MARK: - Internal cache

    private static let cache = WordlistCache()

    private static func cachedWordlist() throws -> Wordlist {
        try cache.get()
    }

    private final class WordlistCache: @unchecked Sendable {
        private var stored: Wordlist?
        private let lock = NSLock()

        func get() throws -> Wordlist {
            lock.lock()
            defer { lock.unlock() }
            if let stored { return stored }
            let loaded = try Wordlist.bundled()
            stored = loaded
            return loaded
        }
    }
}
