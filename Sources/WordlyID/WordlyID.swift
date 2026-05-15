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
