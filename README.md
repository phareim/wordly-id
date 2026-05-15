# wordly-id

Stable, readable identifiers of the form `<PREFIX>-<WORD>-<WORD>-<WORD>` (e.g. `W-COPPER-DRIFTING-LANTERN`), plus a small set of reference primitives — markdown tokenizer, title mirror, slash palette, chip view — for cross-app references between SwiftPM apps that share this identity scheme.

See [docs/specs/2026-05-15-wordly-id-and-refs-design.md](docs/specs/2026-05-15-wordly-id-and-refs-design.md) for the full design and [docs/plans/2026-05-15-wordly-id-package.md](docs/plans/2026-05-15-wordly-id-package.md) for the v0.1 implementation plan.

## Status

v0.1 — first cut. Will be used by [Write](https://github.com/phareim/write) and [Do](https://github.com/phareim/do).

## Two products

- **`WordlyID`** — pure ID generation. No SwiftUI, no Foundation.URL, no SQLite.
- **`WordlyRefs`** — reference primitives. Depends on `WordlyID` + Foundation + system SQLite + SwiftUI (the SwiftUI surface is gated on `#if canImport(SwiftUI)` so the package still builds on Linux).

## Quick start

```swift
import WordlyID

let id = WordlyID.generate(prefix: "W")
// → "W-COPPER-DRIFTING-LANTERN"

let unique = WordlyID.generate(prefix: "DO") { candidate in
    !taskStore.contains(candidate)
}

if let parsed = WordlyID.parse("W-COPPER-DRIFTING-LANTERN") {
    print(parsed.prefix)  // "W"
    print(parsed.words)   // ["COPPER", "DRIFTING", "LANTERN"]
}
```

```swift
import WordlyRefs

// Define a kind per cross-referenced item type
enum WriteKind: ReferenceKind {
    static let prefix = "W"
    static let slashTrigger = "write"
    static let urlScheme = "write"
    static let titlesEndpoint = URL(string: "https://example.com/write/sync/titles")!
    typealias Item = WriteTitleRow  // your Codable item type
}

// Build a mirror; refresh from `GET /titles?since=<seq>` on launch and periodically
let mirror = try await TitleMirror(
    kinds: [AnyReferenceKind(WriteKind.self)],
    storage: appSupport.appendingPathComponent("titles.sqlite"),
    transport: MyHTTPTransport(apiKey: …)
)
try await mirror.refresh(kind: WriteKind.self)

// Search live as the user types after `/write `:
let hits = await mirror.search(query: "migr", kind: AnyReferenceKind(WriteKind.self), limit: 8)

// Tokenize markdown to find inline references:
let tokens = Tokenizer.findReferences(in: docText, schemes: ["write", "do"])
```

## Wordlist

~2,400 curated words (~800 nouns, ~800 adjectives, ~800 verbs), derived from the EFF Long Wordlist with a hand-tuned exclusion list. See `scripts/gen_wordlist.py` for the one-shot generation script. To regenerate on a fresh machine:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install nltk

# On newer nltk (>=3.9) the perceptron tagger was renamed.
# If the default `averaged_perceptron_tagger` download fails, run:
python3 -c "import nltk; nltk.download('averaged_perceptron_tagger_eng'); nltk.download('punkt')"

python3 scripts/gen_wordlist.py
```

## Cross-platform notes

- macOS, iOS: builds natively. Apple's `SQLite3` module is automatically available; this package uses its own `CSQLite` system library target to also build on Linux.
- Linux: requires `libsqlite3-dev` (`sudo apt install libsqlite3-dev`). The SwiftUI `ChipView` surface is excluded automatically via `#if canImport(SwiftUI)`.

## License

MIT.
