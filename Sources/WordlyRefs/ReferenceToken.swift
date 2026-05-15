import Foundation

/// A reference parsed from markdown source. Lossless: the original autolink
/// can be reconstructed as `<\(kindPrefix.lowercased()):\(wordlyID)>`.
public struct ReferenceToken: Equatable, Sendable {
    /// Lowercase URL-scheme equivalent (e.g. "do", "write"). Matches `ReferenceKind.urlScheme`.
    public let scheme: String
    /// The canonical (uppercase) WordlyID.
    public let wordlyID: String
    /// Byte range in the source where the autolink (including angle brackets) lives.
    public let range: Range<String.Index>

    public init(scheme: String, wordlyID: String, range: Range<String.Index>) {
        self.scheme = scheme
        self.wordlyID = wordlyID
        self.range = range
    }
}
