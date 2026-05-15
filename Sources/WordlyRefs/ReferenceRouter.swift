import Foundation

/// Dispatches a tap on a reference chip to either in-app navigation
/// (when the reference's scheme matches the host app) or a URL open
/// using a per-kind URL scheme.
///
/// URL shape: `<scheme>://<scheme>/<wordly_id>`. The path segment
/// echoes the scheme so future routers can distinguish kinds in the
/// same host (e.g. `write://link/L-...`).
public struct ReferenceRouter {
    public let hostScheme: String
    public let openInApp: (_ scheme: String, _ wordlyID: String) -> Bool
    public let openURL: (URL) -> Bool

    public init(
        hostScheme: String,
        openInApp: @escaping (_ scheme: String, _ wordlyID: String) -> Bool,
        openURL: @escaping (URL) -> Bool
    ) {
        self.hostScheme = hostScheme
        self.openInApp = openInApp
        self.openURL = openURL
    }

    @discardableResult
    public func handleTap(scheme: String, wordlyID: String) -> Bool {
        if scheme == hostScheme {
            return openInApp(scheme, wordlyID)
        }
        guard let url = URL(string: "\(scheme)://\(scheme)/\(wordlyID)") else { return false }
        return openURL(url)
    }
}
