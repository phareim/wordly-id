import Foundation

/// Describes one kind of cross-app referenceable item (e.g. "write note" or "do task").
public protocol ReferenceKind {
    /// Uppercase prefix used in the ID (e.g. "W", "DO").
    static var prefix: String { get }

    /// Lowercase trigger word typed after `/` in the slash palette (e.g. "write", "do").
    static var slashTrigger: String { get }

    /// Lowercase URL scheme used for cross-app deep links (e.g. "write", "do").
    static var urlScheme: String { get }

    /// Endpoint exposing `GET <url>?since=<seq>&limit=<n>` returning `TitlesResponse`.
    static var titlesEndpoint: URL { get }

    associatedtype Item: ReferenceItem
}

/// Type-erased view of a `ReferenceKind` so heterogeneous kinds can live in one collection.
public struct AnyReferenceKind: Sendable, Hashable {
    public let prefix: String
    public let slashTrigger: String
    public let urlScheme: String
    public let titlesEndpoint: URL

    public init<K: ReferenceKind>(_ kind: K.Type) {
        self.prefix = K.prefix
        self.slashTrigger = K.slashTrigger
        self.urlScheme = K.urlScheme
        self.titlesEndpoint = K.titlesEndpoint
    }
}

/// One item retrieved from a kind's `/titles` endpoint and cached in the title mirror.
public protocol ReferenceItem: Sendable, Codable, Hashable {
    /// The wordly_id, in canonical uppercase form.
    var wordlyID: String { get }

    /// Current human-readable title.
    var title: String { get }

    /// Server seq / mtime ordering key (milliseconds since epoch).
    var mtime: Int64 { get }

    /// True if the underlying item has been soft-deleted.
    var deleted: Bool { get }

    /// Optional one-glyph badge for the chip (e.g. ● for tasks). Nil for kinds with no status concept.
    var statusGlyph: String? { get }
}
