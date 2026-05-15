import Foundation

/// Extracts reference autolinks (`<scheme:WORDLY-ID>`) from a markdown source.
///
/// Each returned `ReferenceToken` carries a `Range<String.Index>` indexing into
/// the source string. The range is only valid while the caller still owns that
/// exact source; mutating or releasing the source invalidates the range.
public enum Tokenizer {
    /// Find all reference autolinks in `source` whose scheme is in `schemes`.
    /// Returns tokens in source order, non-overlapping.
    public static func findReferences(in source: String, schemes: Set<String>) -> [ReferenceToken] {
        // Pattern: <scheme:WORDLY-ID>
        //   - scheme = one of the allowed lowercase schemes
        //   - WORDLY-ID = uppercase letters and digits separated by single dashes,
        //                 at least 4 segments (PREFIX-W-W-W).
        // Build a single alternation regex from `schemes`.
        let schemeAlternation = schemes.sorted().joined(separator: "|")
        let pattern = "<(\(schemeAlternation)):([A-Z0-9]+(?:-[A-Z0-9]+){3,})>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let ns = source as NSString
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: ns.length))
        var tokens: [ReferenceToken] = []
        for match in matches {
            let fullRange = match.range
            let schemeRange = match.range(at: 1)
            let idRange = match.range(at: 2)
            guard
                let full = Range(fullRange, in: source),
                schemeRange.location != NSNotFound,
                idRange.location != NSNotFound
            else { continue }
            let scheme = ns.substring(with: schemeRange)
            let wordlyID = ns.substring(with: idRange)
            tokens.append(ReferenceToken(scheme: scheme, wordlyID: wordlyID, range: full))
        }
        return tokens
    }
}
