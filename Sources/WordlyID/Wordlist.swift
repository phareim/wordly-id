import Foundation

struct Wordlist: Sendable {
    let nouns: [String]
    let adjectives: [String]
    let verbs: [String]

    enum LoadError: Error {
        case resourceMissing
        case parseFailed(reason: String)
    }

    static func bundled() throws -> Wordlist {
        guard let url = Bundle.module.url(forResource: "Wordlist", withExtension: "txt") else {
            throw LoadError.resourceMissing
        }
        let raw = try String(contentsOf: url, encoding: .utf8)
        return try parse(raw)
    }

    static func parse(_ text: String) throws -> Wordlist {
        var current: String? = nil
        var nouns: [String] = []
        var adjectives: [String] = []
        var verbs: [String] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#") {
                let header = line.dropFirst().trimmingCharacters(in: .whitespaces).lowercased()
                current = header
                continue
            }
            switch current {
            case "noun": nouns.append(line)
            case "adjective": adjectives.append(line)
            case "verb": verbs.append(line)
            case nil:
                throw LoadError.parseFailed(reason: "word \(line) before any section header")
            case .some(let header):
                throw LoadError.parseFailed(reason: "unknown section: \(header)")
            }
        }
        guard !nouns.isEmpty, !adjectives.isEmpty, !verbs.isEmpty else {
            throw LoadError.parseFailed(reason: "one or more sections are empty")
        }
        return Wordlist(nouns: nouns, adjectives: adjectives, verbs: verbs)
    }
}
