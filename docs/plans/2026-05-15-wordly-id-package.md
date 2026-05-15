# WordlyID Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship v0.1 of the `wordly-id` SwiftPM package with two products: `WordlyID` (pure ID generation from a curated wordlist) and `WordlyRefs` (reference primitives — tokenizer, title mirror, slash palette controller, chip view, router) — fully unit-tested.

**Architecture:** SwiftPM package at `~/github/wordly-id/`. Two library products that build cross-platform; SwiftUI surfaces fenced with `#if canImport(SwiftUI)` so the package compiles on Linux CI. Wordlist generated once by a Python script (committed as a deterministic artifact) and embedded as a resource. SQLite via `import SQLite3` (no GRDB dep) to keep the dependency footprint at zero.

**Tech Stack:** Swift 6.0, SwiftPM, `XCTest`, `import SQLite3` (system), `#if canImport(SwiftUI)`, Python 3 + `nltk` for the one-shot wordlist generation script.

---

## File structure

```
~/github/wordly-id/
├── Package.swift
├── README.md
├── LICENSE                                    # MIT
├── .gitignore
├── docs/
│   ├── specs/2026-05-15-wordly-id-and-refs-design.md   (exists)
│   └── plans/2026-05-15-wordly-id-package.md           (this file)
├── scripts/
│   ├── gen_wordlist.py
│   └── eff_large_wordlist.txt                # EFF source, CC0
├── Sources/
│   ├── WordlyID/
│   │   ├── WordlyID.swift                    # public API surface
│   │   ├── Wordlist.swift                    # internal loader
│   │   └── Resources/Wordlist.txt            # generated artifact
│   └── WordlyRefs/
│       ├── ReferenceKind.swift               # ReferenceKind + ReferenceItem protocols
│       ├── ReferenceToken.swift              # token enum used by tokenizer + router
│       ├── Tokenizer.swift                   # regex parser
│       ├── TitleMirror.swift                 # actor + SQLite store
│       ├── SlashPalette.swift                # state machine + bridge protocol
│       ├── ChipView.swift                    # SwiftUI inline chip (#if canImport(SwiftUI))
│       └── ReferenceRouter.swift             # tap dispatch (in-app vs URL scheme)
└── Tests/
    ├── WordlyIDTests/
    │   ├── GenerateTests.swift
    │   ├── ParseValidateTests.swift
    │   └── WordlistTests.swift
    └── WordlyRefsTests/
        ├── MockKind.swift                    # test fixture used by multiple tests
        ├── TokenizerTests.swift
        ├── TitleMirrorTests.swift
        ├── SlashPaletteTests.swift
        └── ReferenceRouterTests.swift
```

Each task below is one focused commit. Steps are bite-sized (2–5 minutes each). Strict TDD: failing test first, then implementation, then green, then commit.

---

### Task 1: Project scaffold

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `README.md`
- Create: `Sources/WordlyID/.gitkeep` (placeholder, deleted in Task 3)
- Create: `Sources/WordlyRefs/.gitkeep` (placeholder, deleted in Task 7)
- Create: `Tests/WordlyIDTests/.gitkeep`
- Create: `Tests/WordlyRefsTests/.gitkeep`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "wordly-id",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "WordlyID", targets: ["WordlyID"]),
        .library(name: "WordlyRefs", targets: ["WordlyRefs"]),
    ],
    targets: [
        .target(
            name: "WordlyID",
            resources: [.process("Resources")]
        ),
        .target(
            name: "WordlyRefs",
            dependencies: ["WordlyID"]
        ),
        .testTarget(
            name: "WordlyIDTests",
            dependencies: ["WordlyID"]
        ),
        .testTarget(
            name: "WordlyRefsTests",
            dependencies: ["WordlyRefs"]
        ),
    ]
)
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
.build/
.swiftpm/
Packages/
*.xcodeproj
*.xcworkspace
DerivedData/
.DS_Store
__pycache__/
*.pyc
.venv/
```

- [ ] **Step 3: Write `LICENSE`**

Use the MIT License with copyright "Copyright (c) 2026 Petter Hareim". Standard MIT text — copy verbatim from <https://opensource.org/license/mit/>, only changing the year and copyright holder.

- [ ] **Step 4: Write `README.md` (stub — final pass in Task 14)**

```markdown
# wordly-id

Stable, readable identifiers of the form `<PREFIX>-<WORD>-<WORD>-<WORD>` (e.g. `W-COPPER-DRIFTING-LANTERN`), plus a small set of reference primitives — markdown tokenizer, title mirror, slash palette, chip view — for cross-app references between SwiftPM apps that share this identity scheme.

See [docs/specs/2026-05-15-wordly-id-and-refs-design.md](docs/specs/2026-05-15-wordly-id-and-refs-design.md) for the full design.

## Status

v0.1 — first cut, used by [Write](https://github.com/phareim/write) and [Do](https://github.com/phareim/do).

## License

MIT.
```

- [ ] **Step 5: Create placeholder dirs so `swift build` accepts the layout**

```bash
mkdir -p Sources/WordlyID/Resources Sources/WordlyRefs Tests/WordlyIDTests Tests/WordlyRefsTests
touch Sources/WordlyID/.gitkeep Sources/WordlyRefs/.gitkeep Tests/WordlyIDTests/.gitkeep Tests/WordlyRefsTests/.gitkeep
```

- [ ] **Step 6: Verify Package.swift parses**

Run: `swift package describe`
Expected: prints the package description without error. (At this stage `swift build` will fail because there are no sources — that's fine; we just want `Package.swift` to parse.)

- [ ] **Step 7: Commit**

```bash
git add Package.swift .gitignore LICENSE README.md Sources Tests
git commit -m "Package scaffold: two products, MIT license, README stub"
```

---

### Task 2: Wordlist generation script + generated wordlist

**Files:**
- Create: `scripts/eff_large_wordlist.txt`
- Create: `scripts/gen_wordlist.py`
- Create: `Sources/WordlyID/Resources/Wordlist.txt`
- Create: `scripts/README.md`

This task is heavier than most because it produces a real artifact. The script runs once; the output is the deliverable. The Swift code in later tasks consumes `Wordlist.txt`, not the script.

- [ ] **Step 1: Vendor the EFF Long Wordlist source**

The EFF Long Wordlist is public domain (CC0). Download from <https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt> and save the **body only** (strip the dice-number prefix on each line — every line is `12345 word`, we want just `word`). Final file `scripts/eff_large_wordlist.txt` should be 7,776 lowercased lines, one word per line.

```bash
curl -sSL https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt \
  | awk '{print $2}' \
  > scripts/eff_large_wordlist.txt
wc -l scripts/eff_large_wordlist.txt
# expected: 7776
```

- [ ] **Step 2: Write the generation script**

`scripts/gen_wordlist.py`:

```python
#!/usr/bin/env python3
"""
Generate Sources/WordlyID/Resources/Wordlist.txt from the EFF Long Wordlist.

Filters by length and an exclusion list, POS-tags via nltk, buckets into
nouns / adjectives / verbs (incl. -ing forms), and samples ~800 of each.

Run once after curation changes. Output is committed.
"""
import os
import random
import sys
from pathlib import Path

import nltk

random.seed(42)  # deterministic output

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "scripts" / "eff_large_wordlist.txt"
OUT = ROOT / "Sources" / "WordlyID" / "Resources" / "Wordlist.txt"

MIN_LEN, MAX_LEN = 3, 9
TARGET_PER_BUCKET = 800

EXCLUDE = {
    # Body parts, medical, awkward in ID contexts
    "armpit", "bowels", "buttocks", "earwax", "phlegm", "pustule", "urinate", "vomit",
    # Slurs / dated / awkward
    "savage", "tribal", "redneck",
    # Confusable / homophone-y
    "knight", "night", "knot", "not",
    # Brands / proper-noun feel
    "olympic",
}


def ensure_nltk():
    for pkg in ("averaged_perceptron_tagger", "punkt"):
        try:
            nltk.data.find(f"taggers/{pkg}") if "tagger" in pkg else nltk.data.find(f"tokenizers/{pkg}")
        except LookupError:
            nltk.download(pkg, quiet=True)


def pos_bucket(tag: str) -> str | None:
    if tag in ("NN", "NNS"):
        return "noun"
    if tag in ("JJ",):
        return "adjective"
    if tag.startswith("VB"):
        # VB, VBD, VBG, VBN, VBP, VBZ — keep VBG ("dancing") for cadence
        return "verb"
    return None


def main() -> int:
    ensure_nltk()
    raw = [w.strip().lower() for w in SRC.read_text().splitlines() if w.strip()]
    filtered = [
        w for w in raw
        if MIN_LEN <= len(w) <= MAX_LEN
        and w.isalpha()
        and w not in EXCLUDE
    ]
    tagged = nltk.pos_tag(filtered)

    buckets: dict[str, list[str]] = {"noun": [], "adjective": [], "verb": []}
    for word, tag in tagged:
        bucket = pos_bucket(tag)
        if bucket:
            buckets[bucket].append(word)

    for bucket, words in buckets.items():
        random.shuffle(words)
        buckets[bucket] = sorted(words[:TARGET_PER_BUCKET])
        print(f"{bucket}: {len(buckets[bucket])} words", file=sys.stderr)
        if len(buckets[bucket]) < TARGET_PER_BUCKET:
            print(f"  WARNING: under target ({TARGET_PER_BUCKET})", file=sys.stderr)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    lines = []
    for bucket in ("noun", "adjective", "verb"):
        lines.append(f"# {bucket}")
        lines.extend(buckets[bucket])
        lines.append("")
    OUT.write_text("\n".join(lines) + "\n")
    print(f"wrote {OUT}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 3: Write `scripts/README.md` explaining one-shot usage**

```markdown
# scripts

Helpers that run once or rarely.

## `gen_wordlist.py`

Generates `Sources/WordlyID/Resources/Wordlist.txt` from `eff_large_wordlist.txt`.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install nltk
python3 scripts/gen_wordlist.py
```

Output is deterministic (seeded). Re-run only when changing the curation rules or the `EXCLUDE` list. The output file is committed; the venv is not.
```

- [ ] **Step 4: Run the generator**

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install nltk
python3 scripts/gen_wordlist.py
```

Expected stderr:
```
noun: 800 words
adjective: 800 words
verb: 800 words
wrote /home/petter/github/wordly-id/Sources/WordlyID/Resources/Wordlist.txt
```

If any bucket comes in under 800, increase MAX_LEN to 10 or relax the EXCLUDE list and re-run. Bucket undershoot is acceptable down to 500 — but document the actual size in `Wordlist.txt`'s header comment by editing TARGET_PER_BUCKET if needed.

- [ ] **Step 5: Sanity-check the output**

```bash
head -5 Sources/WordlyID/Resources/Wordlist.txt
wc -l Sources/WordlyID/Resources/Wordlist.txt
grep -c '^[a-z]\{3,9\}$' Sources/WordlyID/Resources/Wordlist.txt
```

Expected: file starts with `# noun` then words; total lines ≈ 2,403 (2,400 words + 3 headers + 3 blank lines); the `grep -c` count equals the word count (every non-header line is 3–9 lowercase letters).

- [ ] **Step 6: Commit**

```bash
git add scripts/ Sources/WordlyID/Resources/Wordlist.txt
git rm Sources/WordlyID/.gitkeep
git commit -m "Wordlist: EFF-derived, ~800 nouns/adjectives/verbs, deterministic"
```

---

### Task 3: Wordlist loader

**Files:**
- Create: `Sources/WordlyID/Wordlist.swift`
- Create: `Tests/WordlyIDTests/WordlistTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/WordlyIDTests/WordlistTests.swift`:

```swift
import XCTest
@testable import WordlyID

final class WordlistTests: XCTestCase {
    func test_loadsThreePartitions() throws {
        let wordlist = try Wordlist.bundled()
        XCTAssertGreaterThanOrEqual(wordlist.nouns.count, 500, "expected noun bucket of at least 500")
        XCTAssertGreaterThanOrEqual(wordlist.adjectives.count, 500)
        XCTAssertGreaterThanOrEqual(wordlist.verbs.count, 500)
    }

    func test_allWordsAreLowercaseLetters() throws {
        let wordlist = try Wordlist.bundled()
        let all = wordlist.nouns + wordlist.adjectives + wordlist.verbs
        let alphabet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        for word in all {
            XCTAssertFalse(word.isEmpty)
            XCTAssertTrue(
                CharacterSet(charactersIn: word).isSubset(of: alphabet),
                "word should be lowercase letters only: \(word)"
            )
        }
    }

    func test_bucketsAreDisjoint() throws {
        let wordlist = try Wordlist.bundled()
        let nouns = Set(wordlist.nouns)
        let adjectives = Set(wordlist.adjectives)
        let verbs = Set(wordlist.verbs)
        XCTAssertTrue(nouns.intersection(adjectives).isEmpty, "a word may live in only one bucket")
        XCTAssertTrue(nouns.intersection(verbs).isEmpty)
        XCTAssertTrue(adjectives.intersection(verbs).isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter WordlistTests`
Expected: FAIL with `cannot find 'Wordlist' in scope`.

- [ ] **Step 3: Write the loader**

`Sources/WordlyID/Wordlist.swift`:

```swift
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
        return Wordlist(nouns: nouns, adjectives: adjectives, verbs: verbs)
    }
}
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter WordlistTests`
Expected: 3/3 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyID/Wordlist.swift Tests/WordlyIDTests/WordlistTests.swift
git rm Tests/WordlyIDTests/.gitkeep 2>/dev/null || true
git commit -m "Wordlist: parse the bundled three-section text file"
```

---

### Task 4: `WordlyID.generate(prefix:)`

**Files:**
- Create: `Sources/WordlyID/WordlyID.swift`
- Create: `Tests/WordlyIDTests/GenerateTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/WordlyIDTests/GenerateTests.swift`:

```swift
import XCTest
@testable import WordlyID

final class GenerateTests: XCTestCase {
    func test_formatIsPrefixDashThreeUppercaseWords() {
        let id = WordlyID.generate(prefix: "W")
        let parts = id.split(separator: "-").map(String.init)
        XCTAssertEqual(parts.count, 4, "\(id) should split into 4 dash-segments")
        XCTAssertEqual(parts[0], "W")
        for part in parts.dropFirst() {
            XCTAssertFalse(part.isEmpty)
            XCTAssertEqual(part, part.uppercased())
            XCTAssertTrue(part.allSatisfy { $0.isLetter && $0.isASCII })
        }
    }

    func test_acceptsTwoLetterPrefix() {
        let id = WordlyID.generate(prefix: "DO")
        XCTAssertTrue(id.hasPrefix("DO-"))
    }

    func test_acceptsFourLetterPrefix() {
        let id = WordlyID.generate(prefix: "DEMO")
        XCTAssertTrue(id.hasPrefix("DEMO-"))
    }

    func test_consecutiveCallsProduceDistinctIDsWithHighProbability() {
        var seen: Set<String> = []
        for _ in 0..<200 {
            seen.insert(WordlyID.generate(prefix: "T"))
        }
        // 200 draws from 1.6e10 space → essentially zero collision risk.
        XCTAssertEqual(seen.count, 200, "200 consecutive draws should be distinct")
    }

    func test_drawsOneFromEachPartition() {
        // Word 1 comes from nouns, word 2 from adjectives, word 3 from verbs.
        // We can't verify that directly without exposing internals, but we can
        // assert that the partition membership matches the bundled wordlist.
        let wordlist = try! Wordlist.bundled()
        let nouns = Set(wordlist.nouns.map { $0.uppercased() })
        let adjectives = Set(wordlist.adjectives.map { $0.uppercased() })
        let verbs = Set(wordlist.verbs.map { $0.uppercased() })
        var nounHits = 0
        var adjectiveHits = 0
        var verbHits = 0
        for _ in 0..<50 {
            let parts = WordlyID.generate(prefix: "T").split(separator: "-").map(String.init)
            if nouns.contains(parts[1]) { nounHits += 1 }
            if adjectives.contains(parts[2]) { adjectiveHits += 1 }
            if verbs.contains(parts[3]) { verbHits += 1 }
        }
        XCTAssertEqual(nounHits, 50, "every word-1 should be a noun")
        XCTAssertEqual(adjectiveHits, 50, "every word-2 should be an adjective")
        XCTAssertEqual(verbHits, 50, "every word-3 should be a verb")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter GenerateTests`
Expected: FAIL with `cannot find 'WordlyID' in scope`.

- [ ] **Step 3: Write the minimal implementation**

`Sources/WordlyID/WordlyID.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter GenerateTests`
Expected: 5/5 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyID/WordlyID.swift Tests/WordlyIDTests/GenerateTests.swift
git commit -m "WordlyID.generate(prefix:) — three-bucket draw"
```

---

### Task 5: `WordlyID.generate(prefix:isUnique:)` with retry

**Files:**
- Modify: `Sources/WordlyID/WordlyID.swift`
- Modify: `Tests/WordlyIDTests/GenerateTests.swift`

- [ ] **Step 1: Add failing tests for the uniqueness variant**

Append to `Tests/WordlyIDTests/GenerateTests.swift`:

```swift
    func test_isUniqueCallback_returnsFirstAcceptedID() {
        let id = WordlyID.generate(prefix: "T", isUnique: { _ in true })
        XCTAssertTrue(id.hasPrefix("T-"))
    }

    func test_isUniqueCallback_retriesOnCollision() {
        var attempts = 0
        let id = WordlyID.generate(prefix: "T", isUnique: { _ in
            attempts += 1
            return attempts >= 2  // first attempt rejected, second accepted
        })
        XCTAssertEqual(attempts, 2)
        XCTAssertTrue(id.hasPrefix("T-"))
    }

    func test_isUniqueCallback_fallsBackToSuffixAfterThreeRejections() {
        var attempts = 0
        let id = WordlyID.generate(prefix: "T", isUnique: { candidate in
            attempts += 1
            // Reject the first 3 fresh draws; accept anything with a suffix.
            if candidate.hasSuffix("-2") || candidate.hasSuffix("-3") || candidate.hasSuffix("-4") {
                return true
            }
            return false
        })
        XCTAssertGreaterThanOrEqual(attempts, 4, "should attempt at least 3 draws + 1 suffix")
        XCTAssertTrue(id.hasSuffix("-2"), "first fallback suffix should be -2; got \(id)")
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --filter GenerateTests`
Expected: FAIL — `generate(prefix:isUnique:)` not declared.

- [ ] **Step 3: Implement the uniqueness variant**

Add to `Sources/WordlyID/WordlyID.swift` inside the `WordlyID` enum, after the existing `generate(prefix:)`:

```swift
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
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter GenerateTests`
Expected: 8/8 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyID/WordlyID.swift Tests/WordlyIDTests/GenerateTests.swift
git commit -m "WordlyID.generate(prefix:isUnique:) — retry then suffix fallback"
```

---

### Task 6: `parse` and `validate`

**Files:**
- Modify: `Sources/WordlyID/WordlyID.swift`
- Create: `Tests/WordlyIDTests/ParseValidateTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/WordlyIDTests/ParseValidateTests.swift`:

```swift
import XCTest
@testable import WordlyID

final class ParseValidateTests: XCTestCase {
    func test_parse_extractsPrefixAndWords() {
        let parsed = WordlyID.parse("W-COPPER-DRIFTING-LANTERN")
        XCTAssertEqual(parsed?.prefix, "W")
        XCTAssertEqual(parsed?.words, ["COPPER", "DRIFTING", "LANTERN"])
    }

    func test_parse_acceptsSuffixAsExtraSegment() {
        let parsed = WordlyID.parse("W-COPPER-DRIFTING-LANTERN-2")
        XCTAssertEqual(parsed?.prefix, "W")
        XCTAssertEqual(parsed?.words, ["COPPER", "DRIFTING", "LANTERN", "2"])
    }

    func test_parse_rejectsTooFewSegments() {
        XCTAssertNil(WordlyID.parse("W-COPPER-DRIFTING"))
        XCTAssertNil(WordlyID.parse("W-COPPER"))
        XCTAssertNil(WordlyID.parse("W"))
        XCTAssertNil(WordlyID.parse(""))
    }

    func test_parse_rejectsLowercase() {
        XCTAssertNil(WordlyID.parse("w-copper-drifting-lantern"))
    }

    func test_parse_rejectsEmptySegments() {
        XCTAssertNil(WordlyID.parse("W--DRIFTING-LANTERN"))
        XCTAssertNil(WordlyID.parse("-COPPER-DRIFTING-LANTERN"))
    }

    func test_validate_acceptsCanonicalRoundtrip() {
        let generated = WordlyID.generate(prefix: "W")
        XCTAssertTrue(WordlyID.validate(generated))
    }

    func test_validate_rejectsObviousJunk() {
        XCTAssertFalse(WordlyID.validate("nope"))
        XCTAssertFalse(WordlyID.validate("W-copper-DRIFTING-LANTERN"))
        XCTAssertFalse(WordlyID.validate("W-COPPER-DRIFTING-LANTERN!"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ParseValidateTests`
Expected: FAIL — `parse` and `validate` not declared.

- [ ] **Step 3: Add `parse` and `validate` to `WordlyID`**

Append inside the `WordlyID` enum in `Sources/WordlyID/WordlyID.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter ParseValidateTests`
Expected: 7/7 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyID/WordlyID.swift Tests/WordlyIDTests/ParseValidateTests.swift
git commit -m "WordlyID.parse / .validate"
```

---

### Task 7: ReferenceKind + ReferenceItem protocols

**Files:**
- Create: `Sources/WordlyRefs/ReferenceKind.swift`
- Create: `Sources/WordlyRefs/ReferenceToken.swift`
- Create: `Tests/WordlyRefsTests/MockKind.swift`

These are pure type definitions, but we still write at least one compile-checking test to lock the surface.

- [ ] **Step 1: Write protocols and token**

`Sources/WordlyRefs/ReferenceKind.swift`:

```swift
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
```

`Sources/WordlyRefs/ReferenceToken.swift`:

```swift
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
```

- [ ] **Step 2: Write a Mock kind for tests to use**

`Tests/WordlyRefsTests/MockKind.swift`:

```swift
import Foundation
@testable import WordlyRefs

struct MockItem: ReferenceItem {
    let wordlyID: String
    let title: String
    let mtime: Int64
    let deleted: Bool
    let statusGlyph: String?
}

enum WriteMockKind: ReferenceKind {
    static let prefix = "W"
    static let slashTrigger = "write"
    static let urlScheme = "write"
    static let titlesEndpoint = URL(string: "https://example.test/write/sync/titles")!
    typealias Item = MockItem
}

enum DoMockKind: ReferenceKind {
    static let prefix = "DO"
    static let slashTrigger = "do"
    static let urlScheme = "do"
    static let titlesEndpoint = URL(string: "https://example.test/tasks/titles")!
    typealias Item = MockItem
}
```

- [ ] **Step 3: Add a trivial smoke test that confirms the protocol compiles and AnyReferenceKind erases correctly**

Append to `Tests/WordlyRefsTests/MockKind.swift`:

```swift
import XCTest

final class ReferenceKindSmokeTests: XCTestCase {
    func test_anyReferenceKindCopiesStaticFields() {
        let any = AnyReferenceKind(WriteMockKind.self)
        XCTAssertEqual(any.prefix, "W")
        XCTAssertEqual(any.slashTrigger, "write")
        XCTAssertEqual(any.urlScheme, "write")
        XCTAssertEqual(any.titlesEndpoint.absoluteString, "https://example.test/write/sync/titles")
    }

    func test_anyReferenceKindIsHashable() {
        let a = AnyReferenceKind(WriteMockKind.self)
        let b = AnyReferenceKind(WriteMockKind.self)
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set([a, b]).count, 1)
    }
}
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter ReferenceKindSmokeTests`
Expected: 2/2 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyRefs/ReferenceKind.swift Sources/WordlyRefs/ReferenceToken.swift Tests/WordlyRefsTests/MockKind.swift
git rm Sources/WordlyRefs/.gitkeep Tests/WordlyRefsTests/.gitkeep 2>/dev/null || true
git commit -m "WordlyRefs: ReferenceKind, ReferenceItem, AnyReferenceKind, ReferenceToken"
```

---

### Task 8: Markdown tokenizer

**Files:**
- Create: `Sources/WordlyRefs/Tokenizer.swift`
- Create: `Tests/WordlyRefsTests/TokenizerTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/WordlyRefsTests/TokenizerTests.swift`:

```swift
import XCTest
@testable import WordlyRefs

final class TokenizerTests: XCTestCase {
    let schemes: Set<String> = ["do", "write"]

    func test_findsSingleReference() {
        let source = "Discuss in <do:DO-RABBIT-DANCING-MAUVE>."
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].scheme, "do")
        XCTAssertEqual(tokens[0].wordlyID, "DO-RABBIT-DANCING-MAUVE")
        XCTAssertEqual(source[tokens[0].range], "<do:DO-RABBIT-DANCING-MAUVE>")
    }

    func test_findsAdjacentReferencesOfDifferentKinds() {
        let source = "<write:W-COPPER-DRIFTING-LANTERN><do:DO-RABBIT-DANCING-MAUVE>"
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].scheme, "write")
        XCTAssertEqual(tokens[1].scheme, "do")
    }

    func test_ignoresUnknownSchemes() {
        let source = "Check <link:L-FOO-BAR-BAZ> for more."
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertTrue(tokens.isEmpty)
    }

    func test_ignoresLowercaseWordlyID() {
        let source = "<do:do-rabbit-dancing-mauve>"
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertTrue(tokens.isEmpty)
    }

    func test_ignoresMissingAngleBrackets() {
        let source = "do:DO-RABBIT-DANCING-MAUVE"
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertTrue(tokens.isEmpty)
    }

    func test_acceptsSuffixedID() {
        let source = "<do:DO-RABBIT-DANCING-MAUVE-2>"
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].wordlyID, "DO-RABBIT-DANCING-MAUVE-2")
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter TokenizerTests`
Expected: FAIL — `Tokenizer` not in scope.

- [ ] **Step 3: Write the tokenizer**

`Sources/WordlyRefs/Tokenizer.swift`:

```swift
import Foundation

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
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter TokenizerTests`
Expected: 6/6 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyRefs/Tokenizer.swift Tests/WordlyRefsTests/TokenizerTests.swift
git commit -m "WordlyRefs: Tokenizer.findReferences"
```

---

### Task 9: TitleMirror — schema + refresh

**Files:**
- Create: `Sources/WordlyRefs/TitleMirror.swift`
- Create: `Tests/WordlyRefsTests/TitleMirrorTests.swift`

`TitleMirror` is the biggest single component. Split into two tasks: this one stands up the SQLite store and the refresh-from-endpoint behavior; Task 10 layers search and resolve on top.

- [ ] **Step 1: Write the failing tests for schema + refresh**

`Tests/WordlyRefsTests/TitleMirrorTests.swift`:

```swift
import XCTest
@testable import WordlyRefs

final class TitleMirrorSchemaTests: XCTestCase {
    var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordly-refs-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func test_openCreatesSchema() async throws {
        let mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self), AnyReferenceKind(DoMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: StubTransport()
        )
        let cursor = await mirror.cursor(for: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(cursor, 0)
    }

    func test_refreshAdvancesCursorAndStoresRows() async throws {
        let stub = StubTransport()
        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            .init(cursor: 42, items: [
                MockItem(wordlyID: "W-A-B-C", title: "First note", mtime: 100, deleted: false, statusGlyph: nil),
                MockItem(wordlyID: "W-D-E-F", title: "Second", mtime: 200, deleted: false, statusGlyph: nil),
            ])
        ]
        let mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: stub
        )
        try await mirror.refresh(kind: WriteMockKind.self)
        let cursor = await mirror.cursor(for: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(cursor, 42)
        let count = await mirror.count(kind: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(count, 2)
    }

    func test_refreshPaginatesUntilEmpty() async throws {
        let stub = StubTransport()
        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            .init(cursor: 10, items: [MockItem(wordlyID: "W-A-B-C", title: "p1", mtime: 1, deleted: false, statusGlyph: nil)]),
            .init(cursor: 20, items: [MockItem(wordlyID: "W-D-E-F", title: "p2", mtime: 2, deleted: false, statusGlyph: nil)]),
            .init(cursor: 20, items: []),  // empty page terminates
        ]
        let mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: stub
        )
        try await mirror.refresh(kind: WriteMockKind.self)
        XCTAssertEqual(await mirror.cursor(for: AnyReferenceKind(WriteMockKind.self)), 20)
        XCTAssertEqual(await mirror.count(kind: AnyReferenceKind(WriteMockKind.self)), 2)
    }

    func test_refreshHandlesSoftDeletes() async throws {
        let stub = StubTransport()
        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            .init(cursor: 10, items: [MockItem(wordlyID: "W-A-B-C", title: "alive", mtime: 1, deleted: false, statusGlyph: nil)]),
        ]
        let mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: stub
        )
        try await mirror.refresh(kind: WriteMockKind.self)
        XCTAssertEqual(await mirror.count(kind: AnyReferenceKind(WriteMockKind.self)), 1)

        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            .init(cursor: 11, items: [MockItem(wordlyID: "W-A-B-C", title: "alive", mtime: 1, deleted: true, statusGlyph: nil)]),
        ]
        try await mirror.refresh(kind: WriteMockKind.self)
        XCTAssertEqual(await mirror.count(kind: AnyReferenceKind(WriteMockKind.self)), 0,
                       "soft-deleted rows are pruned from the local store")
    }
}

// MARK: - Test helpers

final class StubTransport: TitleMirrorTransport, @unchecked Sendable {
    /// One queue of `TitlesPage` per kind, drained in order on each refresh call.
    var responses: [AnyReferenceKind: [TitlesPage<MockItem>]] = [:]
    private let lock = NSLock()

    func fetchPage<K: ReferenceKind>(kind: K.Type, since: Int64, limit: Int) async throws -> TitlesPage<K.Item> {
        lock.lock()
        defer { lock.unlock() }
        let key = AnyReferenceKind(kind)
        guard var queue = responses[key], !queue.isEmpty else {
            return TitlesPage<K.Item>(cursor: since, items: [])
        }
        let next = queue.removeFirst()
        responses[key] = queue
        // All test kinds use Item = MockItem, so this cast is safe at runtime.
        return next as! TitlesPage<K.Item>
    }
}
```

- [ ] **Step 2: Run tests — expect failure (TitleMirror not defined)**

Run: `swift test --filter TitleMirrorSchemaTests`
Expected: FAIL — many symbols missing.

- [ ] **Step 3: Implement TitleMirror + transport protocol**

`Sources/WordlyRefs/TitleMirror.swift`:

```swift
import Foundation
import SQLite3

/// One page of items from a kind's `/titles` endpoint.
public struct TitlesPage<Item: ReferenceItem>: Sendable {
    public let cursor: Int64
    public let items: [Item]

    public init(cursor: Int64, items: [Item]) {
        self.cursor = cursor
        self.items = items
    }
}

/// Pluggable transport so tests can stub network calls.
public protocol TitleMirrorTransport: Sendable {
    func fetchPage<K: ReferenceKind>(kind: K.Type, since: Int64, limit: Int) async throws -> TitlesPage<K.Item>
}

/// Local SQLite-backed mirror of one or more kinds' title indexes.
public actor TitleMirror {
    private let kinds: [AnyReferenceKind]
    private let transport: TitleMirrorTransport
    private var db: OpaquePointer?
    private static let pageLimit: Int = 200

    public init(kinds: [AnyReferenceKind], storage: URL, transport: TitleMirrorTransport) async throws {
        self.kinds = kinds
        self.transport = transport
        try openDB(at: storage)
        try createSchema()
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private func openDB(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        var handle: OpaquePointer?
        guard sqlite3_open(url.path, &handle) == SQLITE_OK else {
            throw TitleMirrorError.openFailed(reason: String(cString: sqlite3_errmsg(handle)))
        }
        self.db = handle
    }

    private func createSchema() throws {
        // Per kind, a titles table keyed by wordly_id.
        for kind in kinds {
            let table = Self.tableName(for: kind)
            let createSQL = """
            CREATE TABLE IF NOT EXISTS \(table) (
              wordly_id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              mtime INTEGER NOT NULL,
              deleted INTEGER NOT NULL DEFAULT 0,
              status_glyph TEXT,
              raw_json BLOB NOT NULL
            );
            """
            try exec(createSQL)
            try exec("CREATE INDEX IF NOT EXISTS idx_\(table)_title ON \(table)(title);")
            try exec("CREATE INDEX IF NOT EXISTS idx_\(table)_mtime ON \(table)(mtime DESC);")
        }
        try exec("""
        CREATE TABLE IF NOT EXISTS cursors (
          kind_prefix TEXT PRIMARY KEY,
          cursor INTEGER NOT NULL DEFAULT 0
        );
        """)
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw TitleMirrorError.sqlite(message: message, sql: sql)
        }
    }

    private static func tableName(for kind: AnyReferenceKind) -> String {
        "titles_" + kind.prefix.lowercased()
    }

    // MARK: - Public surface

    public func cursor(for kind: AnyReferenceKind) -> Int64 {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT cursor FROM cursors WHERE kind_prefix = ?", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        sqlite3_bind_text(stmt, 1, kind.prefix, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int64(stmt, 0)
    }

    public func count(kind: AnyReferenceKind) -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let table = Self.tableName(for: kind)
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table) WHERE deleted = 0", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    public func refresh<K: ReferenceKind>(kind kindType: K.Type) async throws {
        let anyKind = AnyReferenceKind(kindType)
        var cursor = self.cursor(for: anyKind)
        while true {
            let page = try await transport.fetchPage(kind: kindType, since: cursor, limit: Self.pageLimit)
            try await apply(page: page, kind: anyKind)
            if page.items.isEmpty { break }
            if page.cursor <= cursor { break }
            cursor = page.cursor
        }
    }

    private func apply<Item: ReferenceItem>(page: TitlesPage<Item>, kind: AnyReferenceKind) async throws {
        let table = Self.tableName(for: kind)
        try exec("BEGIN")
        for item in page.items {
            let raw = try JSONEncoder().encode(item)
            if item.deleted {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                guard sqlite3_prepare_v2(db, "DELETE FROM \(table) WHERE wordly_id = ?", -1, &stmt, nil) == SQLITE_OK else {
                    try exec("ROLLBACK")
                    throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "DELETE")
                }
                sqlite3_bind_text(stmt, 1, item.wordlyID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                if sqlite3_step(stmt) != SQLITE_DONE {
                    try exec("ROLLBACK")
                    throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "DELETE step")
                }
            } else {
                let sql = """
                INSERT INTO \(table) (wordly_id, title, mtime, deleted, status_glyph, raw_json)
                VALUES (?, ?, ?, 0, ?, ?)
                ON CONFLICT(wordly_id) DO UPDATE SET
                  title = excluded.title,
                  mtime = excluded.mtime,
                  deleted = excluded.deleted,
                  status_glyph = excluded.status_glyph,
                  raw_json = excluded.raw_json;
                """
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    try exec("ROLLBACK")
                    throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "UPSERT prepare")
                }
                sqlite3_bind_text(stmt, 1, item.wordlyID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(stmt, 2, item.title, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_int64(stmt, 3, item.mtime)
                if let glyph = item.statusGlyph {
                    sqlite3_bind_text(stmt, 4, glyph, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
                _ = raw.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(stmt, 5, bytes.baseAddress, Int32(bytes.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
                if sqlite3_step(stmt) != SQLITE_DONE {
                    try exec("ROLLBACK")
                    throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "UPSERT step")
                }
            }
        }
        // Update cursor.
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "INSERT INTO cursors (kind_prefix, cursor) VALUES (?, ?) ON CONFLICT(kind_prefix) DO UPDATE SET cursor = excluded.cursor", -1, &stmt, nil) == SQLITE_OK else {
            try exec("ROLLBACK")
            throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "cursor upsert prepare")
        }
        sqlite3_bind_text(stmt, 1, kind.prefix, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int64(stmt, 2, page.cursor)
        if sqlite3_step(stmt) != SQLITE_DONE {
            try exec("ROLLBACK")
            throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "cursor upsert step")
        }
        try exec("COMMIT")
    }
}

public enum TitleMirrorError: Error {
    case openFailed(reason: String)
    case sqlite(message: String, sql: String)
}
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter TitleMirrorSchemaTests`
Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyRefs/TitleMirror.swift Tests/WordlyRefsTests/TitleMirrorTests.swift
git commit -m "WordlyRefs: TitleMirror — SQLite schema, refresh, paginate, soft-delete"
```

---

### Task 10: TitleMirror — search + resolve

**Files:**
- Modify: `Sources/WordlyRefs/TitleMirror.swift`
- Modify: `Tests/WordlyRefsTests/TitleMirrorTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `Tests/WordlyRefsTests/TitleMirrorTests.swift`:

```swift
final class TitleMirrorSearchTests: XCTestCase {
    var tmpDir: URL!
    var mirror: TitleMirror!

    override func setUp() async throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordly-refs-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let stub = StubTransport()
        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            .init(cursor: 100, items: [
                MockItem(wordlyID: "W-COPPER-DRIFTING-LANTERN", title: "Project Migrate Auth", mtime: 300, deleted: false, statusGlyph: nil),
                MockItem(wordlyID: "W-AMBER-WHISPERING-WAVES",  title: "Migration plan",        mtime: 200, deleted: false, statusGlyph: nil),
                MockItem(wordlyID: "W-IRON-WANDERING-OAK",      title: "Unrelated thoughts",    mtime: 100, deleted: false, statusGlyph: nil),
            ])
        ]
        mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: stub
        )
        try await mirror.refresh(kind: WriteMockKind.self)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func test_searchByPrefix() async throws {
        let hits = await mirror.search(query: "Migr", kind: AnyReferenceKind(WriteMockKind.self), limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].title, "Migration plan")
    }

    func test_searchBySubstringFallsBackWhenNoPrefixHit() async throws {
        let hits = await mirror.search(query: "Auth", kind: AnyReferenceKind(WriteMockKind.self), limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].title, "Project Migrate Auth")
    }

    func test_searchIsCaseInsensitive() async throws {
        let hits = await mirror.search(query: "migr", kind: AnyReferenceKind(WriteMockKind.self), limit: 10)
        XCTAssertGreaterThanOrEqual(hits.count, 1)
    }

    func test_searchRespectsLimit() async throws {
        let hits = await mirror.search(query: "", kind: AnyReferenceKind(WriteMockKind.self), limit: 2)
        XCTAssertEqual(hits.count, 2)
    }

    func test_resolveReturnsItem() async throws {
        let item = await mirror.resolve("W-COPPER-DRIFTING-LANTERN", kind: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(item?.title, "Project Migrate Auth")
    }

    func test_resolveReturnsNilForUnknownID() async throws {
        let item = await mirror.resolve("W-NOPE-NOPE-NOPE", kind: AnyReferenceKind(WriteMockKind.self))
        XCTAssertNil(item)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter TitleMirrorSearchTests`
Expected: FAIL — `search` and `resolve` not declared on TitleMirror.

- [ ] **Step 3: Add a `Hit` type and the `search` / `resolve` methods**

Append to `Sources/WordlyRefs/TitleMirror.swift` inside the `TitleMirror` actor:

```swift
    public struct Hit: Sendable, Hashable {
        public let wordlyID: String
        public let title: String
        public let mtime: Int64
        public let statusGlyph: String?
    }

    public func search(query: String, kind: AnyReferenceKind, limit: Int) -> [Hit] {
        guard let db else { return [] }
        let table = Self.tableName(for: kind)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Two-pass: prefix matches first (ordered by mtime DESC), then substring matches
        // excluding the prefix ones (ordered by mtime DESC). Empty query → mtime DESC only.
        var hits: [Hit] = []
        if q.isEmpty {
            let sql = "SELECT wordly_id, title, mtime, status_glyph FROM \(table) WHERE deleted = 0 ORDER BY mtime DESC LIMIT ?"
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                hits.append(rowToHit(stmt!))
            }
            return hits
        }

        let prefixSQL = "SELECT wordly_id, title, mtime, status_glyph FROM \(table) WHERE deleted = 0 AND LOWER(title) LIKE ? ORDER BY mtime DESC LIMIT ?"
        var prefixStmt: OpaquePointer?
        defer { sqlite3_finalize(prefixStmt) }
        guard sqlite3_prepare_v2(db, prefixSQL, -1, &prefixStmt, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_text(prefixStmt, 1, "\(q)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(prefixStmt, 2, Int32(limit))
        while sqlite3_step(prefixStmt) == SQLITE_ROW {
            hits.append(rowToHit(prefixStmt!))
        }
        if hits.count >= limit { return hits }

        let remaining = limit - hits.count
        let knownIDs = Set(hits.map(\.wordlyID))
        let substringSQL = "SELECT wordly_id, title, mtime, status_glyph FROM \(table) WHERE deleted = 0 AND LOWER(title) LIKE ? ORDER BY mtime DESC LIMIT ?"
        var subStmt: OpaquePointer?
        defer { sqlite3_finalize(subStmt) }
        guard sqlite3_prepare_v2(db, substringSQL, -1, &subStmt, nil) == SQLITE_OK else { return hits }
        sqlite3_bind_text(subStmt, 1, "%\(q)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(subStmt, 2, Int32(remaining + hits.count))  // overdraw, then filter
        while sqlite3_step(subStmt) == SQLITE_ROW {
            let hit = rowToHit(subStmt!)
            if !knownIDs.contains(hit.wordlyID) {
                hits.append(hit)
                if hits.count >= limit { break }
            }
        }
        return hits
    }

    public func resolve(_ wordlyID: String, kind: AnyReferenceKind) -> Hit? {
        guard let db else { return nil }
        let table = Self.tableName(for: kind)
        let sql = "SELECT wordly_id, title, mtime, status_glyph FROM \(table) WHERE wordly_id = ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, wordlyID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return rowToHit(stmt!)
    }

    private func rowToHit(_ stmt: OpaquePointer) -> Hit {
        let wordlyID = String(cString: sqlite3_column_text(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let mtime = sqlite3_column_int64(stmt, 2)
        let glyph: String?
        if let cstr = sqlite3_column_text(stmt, 3) {
            glyph = String(cString: cstr)
        } else {
            glyph = nil
        }
        return Hit(wordlyID: wordlyID, title: title, mtime: mtime, statusGlyph: glyph)
    }
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter TitleMirrorSearchTests`
Expected: 6/6 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyRefs/TitleMirror.swift Tests/WordlyRefsTests/TitleMirrorTests.swift
git commit -m "WordlyRefs: TitleMirror.search (prefix then substring) and .resolve"
```

---

### Task 11: SlashPalette controller

**Files:**
- Create: `Sources/WordlyRefs/SlashPalette.swift`
- Create: `Tests/WordlyRefsTests/SlashPaletteTests.swift`

This is a pure-logic state machine. SwiftUI presentation lands in the consuming app (Plan D and Plan E), not here.

- [ ] **Step 1: Write failing tests**

`Tests/WordlyRefsTests/SlashPaletteTests.swift`:

```swift
import XCTest
@testable import WordlyRefs

final class SlashPaletteTests: XCTestCase {
    func test_detectsTriggerAtStartOfLine() {
        let result = SlashPalette.detectTrigger(in: "/do quer", caretIndex: 7, schemes: ["do", "write"])
        XCTAssertEqual(result?.trigger, "do")
        XCTAssertEqual(result?.query, "que")  // characters after "/do " up to caret
        XCTAssertEqual(result?.triggerStart, 0)
    }

    func test_detectsTriggerAfterWhitespace() {
        let source = "see /write proj"
        let result = SlashPalette.detectTrigger(in: source, caretIndex: source.count, schemes: ["do", "write"])
        XCTAssertEqual(result?.trigger, "write")
        XCTAssertEqual(result?.query, "proj")
        XCTAssertEqual(result?.triggerStart, 4)
    }

    func test_ignoresSlashMidWord() {
        // path-like, not at word boundary
        let source = "config/do/settings"
        let result = SlashPalette.detectTrigger(in: source, caretIndex: source.count, schemes: ["do", "write"])
        XCTAssertNil(result)
    }

    func test_ignoresUnknownTriggerWord() {
        let source = "/link foo"
        let result = SlashPalette.detectTrigger(in: source, caretIndex: source.count, schemes: ["do", "write"])
        XCTAssertNil(result)
    }

    func test_requiresSpaceAfterTriggerWord() {
        let source = "/dosomething"  // no space — not a trigger
        let result = SlashPalette.detectTrigger(in: source, caretIndex: source.count, schemes: ["do", "write"])
        XCTAssertNil(result)
    }

    func test_buildsInsertion() {
        let insertion = SlashPalette.insertion(forSelectedID: "DO-COPPER-DRIFTING-LANTERN", scheme: "do")
        XCTAssertEqual(insertion, "<do:DO-COPPER-DRIFTING-LANTERN>")
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter SlashPaletteTests`
Expected: FAIL — `SlashPalette` not declared.

- [ ] **Step 3: Implement the state machine**

`Sources/WordlyRefs/SlashPalette.swift`:

```swift
import Foundation

public enum SlashPalette {
    public struct TriggerMatch: Equatable {
        /// The lowercase trigger word (e.g. "do", "write").
        public let trigger: String
        /// Characters typed by the user after `/<trigger> `, up to the caret.
        public let query: String
        /// Index in the source string where the `/` of the trigger starts.
        /// Used by callers to compute the replacement range when inserting.
        public let triggerStart: Int
    }

    /// Detect whether the caret in `source` sits inside a slash-palette context.
    /// A valid trigger is `/<word> ` where `/` is at a word boundary
    /// (start-of-string or after whitespace), `<word>` is in `schemes`, and a single
    /// space follows. Everything between the space and the caret is the live query.
    public static func detectTrigger(in source: String, caretIndex: Int, schemes: Set<String>) -> TriggerMatch? {
        // Walk backwards from caret looking for a `/` at a word boundary.
        let chars = Array(source)
        guard caretIndex <= chars.count else { return nil }
        // Look back for `/`.
        var i = caretIndex - 1
        while i >= 0 {
            if chars[i] == "/" {
                // Word boundary: i == 0 or chars[i-1] is whitespace.
                if i == 0 || chars[i-1].isWhitespace {
                    let after = String(chars[(i+1)..<caretIndex])
                    // Must be `<word> <query>` — at least one space.
                    guard let spaceIdx = after.firstIndex(of: " ") else { return nil }
                    let word = String(after[..<spaceIdx]).lowercased()
                    guard schemes.contains(word) else { return nil }
                    let query = String(after[after.index(after: spaceIdx)...])
                    // Reject if `query` itself contains a newline — the palette dismisses on newline.
                    if query.contains("\n") { return nil }
                    return TriggerMatch(trigger: word, query: query, triggerStart: i)
                }
                return nil  // `/` was not at a word boundary
            }
            if chars[i].isNewline { return nil }
            i -= 1
        }
        return nil
    }

    /// Compute the reference token that should be inserted when the user selects a result.
    public static func insertion(forSelectedID wordlyID: String, scheme: String) -> String {
        "<\(scheme):\(wordlyID)>"
    }
}
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter SlashPaletteTests`
Expected: 6/6 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyRefs/SlashPalette.swift Tests/WordlyRefsTests/SlashPaletteTests.swift
git commit -m "WordlyRefs: SlashPalette.detectTrigger and .insertion"
```

---

### Task 12: ChipView (SwiftUI)

**Files:**
- Create: `Sources/WordlyRefs/ChipView.swift`

Chip rendering. SwiftUI-only. Test surface is minimal — instantiation under `#if canImport(SwiftUI)`. Visual correctness gets verified in Plans D and E inside the host apps.

- [ ] **Step 1: Write the chip view**

`Sources/WordlyRefs/ChipView.swift`:

```swift
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
```

- [ ] **Step 2: Verify it builds under SwiftPM**

Run: `swift build`
Expected: succeeds with no warnings related to ChipView. (SwiftUI is available on macOS 14, which is our platform floor.)

- [ ] **Step 3: Commit**

```bash
git add Sources/WordlyRefs/ChipView.swift
git commit -m "WordlyRefs: ChipView SwiftUI inline chip with three resolution states"
```

---

### Task 13: ReferenceRouter

**Files:**
- Create: `Sources/WordlyRefs/ReferenceRouter.swift`
- Create: `Tests/WordlyRefsTests/ReferenceRouterTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/WordlyRefsTests/ReferenceRouterTests.swift`:

```swift
import XCTest
@testable import WordlyRefs

final class ReferenceRouterTests: XCTestCase {
    func test_sameSchemeAsHostNavigatesInApp() {
        var inAppCalls: [(scheme: String, id: String)] = []
        let router = ReferenceRouter(
            hostScheme: "write",
            openInApp: { scheme, id in inAppCalls.append((scheme, id)); return true },
            openURL: { _ in XCTFail("should not openURL"); return true }
        )
        let ok = router.handleTap(scheme: "write", wordlyID: "W-A-B-C")
        XCTAssertTrue(ok)
        XCTAssertEqual(inAppCalls.count, 1)
        XCTAssertEqual(inAppCalls[0].scheme, "write")
        XCTAssertEqual(inAppCalls[0].id, "W-A-B-C")
    }

    func test_differentSchemeOpensURL() {
        var urlsOpened: [URL] = []
        let router = ReferenceRouter(
            hostScheme: "write",
            openInApp: { _, _ in XCTFail("should not openInApp"); return true },
            openURL: { url in urlsOpened.append(url); return true }
        )
        let ok = router.handleTap(scheme: "do", wordlyID: "DO-A-B-C")
        XCTAssertTrue(ok)
        XCTAssertEqual(urlsOpened.count, 1)
        XCTAssertEqual(urlsOpened[0].absoluteString, "do://do/DO-A-B-C")
    }

    func test_urlIncludesPathSegmentForKindName() {
        var urlsOpened: [URL] = []
        let router = ReferenceRouter(
            hostScheme: "do",
            openInApp: { _, _ in true },
            openURL: { url in urlsOpened.append(url); return true }
        )
        _ = router.handleTap(scheme: "write", wordlyID: "W-COPPER-DRIFTING-LANTERN")
        XCTAssertEqual(urlsOpened[0].absoluteString, "write://write/W-COPPER-DRIFTING-LANTERN")
    }

    func test_failureFromOpenURLPropagates() {
        let router = ReferenceRouter(
            hostScheme: "write",
            openInApp: { _, _ in true },
            openURL: { _ in false }
        )
        XCTAssertFalse(router.handleTap(scheme: "do", wordlyID: "DO-A-B-C"))
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter ReferenceRouterTests`
Expected: FAIL — `ReferenceRouter` not declared.

- [ ] **Step 3: Implement the router**

`Sources/WordlyRefs/ReferenceRouter.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify green**

Run: `swift test --filter ReferenceRouterTests`
Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WordlyRefs/ReferenceRouter.swift Tests/WordlyRefsTests/ReferenceRouterTests.swift
git commit -m "WordlyRefs: ReferenceRouter — in-app vs URL-scheme dispatch"
```

---

### Task 14: Final polish — README, full test pass, tag

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Run the full test suite**

Run: `swift test`
Expected: every test green; report the count (should be ~40+).

If any test fails, fix it before continuing. Do not skip.

- [ ] **Step 2: Build the package in release mode as a smoke check**

Run: `swift build -c release`
Expected: builds with no warnings or errors.

- [ ] **Step 3: Rewrite `README.md` with usage examples**

```markdown
# wordly-id

Stable, readable identifiers of the form `<PREFIX>-<WORD>-<WORD>-<WORD>` (e.g. `W-COPPER-DRIFTING-LANTERN`), plus a small set of reference primitives — markdown tokenizer, title mirror, slash palette, chip view — for cross-app references between SwiftPM apps that share this identity scheme.

See [docs/specs/2026-05-15-wordly-id-and-refs-design.md](docs/specs/2026-05-15-wordly-id-and-refs-design.md) for the full design.

## Status

v0.1 — used by [Write](https://github.com/phareim/write) and [Do](https://github.com/phareim/do).

## Two products

- **`WordlyID`** — pure ID generation. No SwiftUI, no Foundation.URL.
- **`WordlyRefs`** — reference primitives. Depends on `WordlyID` + SwiftUI.

## Quick start

```swift
import WordlyID

let id = WordlyID.generate(prefix: "W")
// → "W-COPPER-DRIFTING-LANTERN"

let unique = WordlyID.generate(prefix: "DO") { candidate in
    !taskStore.contains(candidate)
}
```

```swift
import WordlyRefs

let mirror = try await TitleMirror(
    kinds: [AnyReferenceKind(WriteKind.self), AnyReferenceKind(DoKind.self)],
    storage: appSupport.appendingPathComponent("titles.sqlite"),
    transport: HTTPTransport(apiKey: …)
)
try await mirror.refresh(kind: DoKind.self)
let hits = await mirror.search(query: "migr", kind: AnyReferenceKind(DoKind.self), limit: 8)
```

## Wordlist

~2,400 curated words (~800 nouns, ~800 adjectives, ~800 verbs), derived from the EFF Long Wordlist with a hand-tuned exclusion list. See `scripts/gen_wordlist.py` for the one-shot generation script.

## License

MIT.
```

- [ ] **Step 4: Commit and tag**

```bash
git add README.md
git commit -m "README: usage examples and product overview for v0.1"
git tag -a v0.1.0 -m "v0.1.0 — initial release: WordlyID + WordlyRefs"
git push origin main --tags
```

---

## Self-review checklist

Run these checks against the spec before declaring the plan done. The plan author already did this once when writing the plan; the implementer should run it again before opening a PR.

- [ ] **Spec §1 (WordlyID package):** covered by Tasks 1, 3–6.
- [ ] **Spec §2 (ReferenceKind protocol):** covered by Task 7.
- [ ] **Spec §3 (on-disk syntax / tokenizer):** covered by Task 8.
- [ ] **Spec §5.1 (TitleMirror):** covered by Tasks 9–10. *Note:* the actual `HTTPTransport` implementation that talks to `/titles` is intentionally NOT in this plan — that lives in the host apps (Plans D and E) since the auth and config are app-specific. This plan delivers the protocol surface and a `StubTransport` for tests.
- [ ] **Spec §5.2 (SlashPalette):** the controller logic is covered by Task 11. The SwiftUI palette view is host-app work (Plans D/E).
- [ ] **Spec §5.3 (ChipView):** covered by Task 12.
- [ ] **Spec §5.4 (ReferenceRouter):** covered by Task 13.
- [ ] **Spec §1.2 collision retry:** covered by Task 5.
- [ ] **Wordlist sourcing (spec §1.3):** covered by Task 2.

Gaps deliberately deferred to host-app plans:
- HTTP transport implementation (auth, retries, JSON shape) → Plans B/C define the endpoint; Plans D/E define the client.
- Frontmatter integration → Plan D.
- URL scheme registration in Info.plist → Plans D/E.
- Visual polish of the chip in Almanac styling → Plans D/E.
