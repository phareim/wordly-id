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
