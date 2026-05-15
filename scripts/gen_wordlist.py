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
