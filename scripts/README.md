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

## Troubleshooting

On nltk ≥ 3.9 the perceptron tagger was renamed. If `gen_wordlist.py` fails with a `LookupError` about `averaged_perceptron_tagger`, pre-download the renamed model:

```bash
python3 -c "import nltk; nltk.download('averaged_perceptron_tagger_eng'); nltk.download('punkt')"
```
