#if canImport(SwiftUI)
import SwiftUI

/// Inline chip representation of a resolved (or unresolved) reference.
public struct ChipView: View {
    public enum Resolution {
        case resolved(title: String, statusGlyph: String?)
        case deleted(lastKnownTitle: String?)
        case unknown(scheme: String, wordlyID: String)
    }

    public let resolution: Resolution
    public let onTap: () -> Void

    public init(resolution: Resolution, onTap: @escaping () -> Void) {
        self.resolution = resolution
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                glyph
                Text(label)
                    .strikethrough(strikethrough)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(background)
            .overlay(border)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var glyph: some View {
        Group {
            switch resolution {
            case .resolved(_, let g):
                if let g { Text(g) }
            case .deleted: Text("⚠")
            case .unknown: Text("⚠")
            }
        }
        .font(.system(size: 10))
    }

    private var label: String {
        switch resolution {
        case .resolved(let title, _): return title
        case .deleted(let last):      return last ?? "deleted"
        case .unknown(let scheme, let id): return "\(scheme):\(id)"
        }
    }

    private var strikethrough: Bool {
        if case .deleted = resolution { return true }
        return false
    }

    private var background: some View {
        let color: Color
        switch resolution {
        case .resolved:           color = Color.primary.opacity(0.05)
        case .deleted:            color = Color.primary.opacity(0.02)
        case .unknown:            color = Color.primary.opacity(0.02)
        }
        return color
    }

    private var border: some View {
        let style: StrokeStyle
        switch resolution {
        case .resolved:           style = StrokeStyle(lineWidth: 0.5)
        case .deleted, .unknown:  style = StrokeStyle(lineWidth: 0.5, dash: [2, 2])
        }
        return RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.25), style: style)
    }

    private var accessibilityText: String {
        switch resolution {
        case .resolved(let title, _): return "reference to \(title)"
        case .deleted(let last):      return "deleted reference to \(last ?? "unknown")"
        case .unknown(let scheme, let id): return "unknown \(scheme) reference \(id)"
        }
    }
}
#endif
