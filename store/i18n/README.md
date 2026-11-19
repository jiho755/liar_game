# store/i18n

- `words_en.json`: English word list. Keys are the Korean category names (same as `WORDS` in `index.html`); `_categories` maps them to the English display names (kept in sync with `I18N.en` `cat.*`). The same data is embedded in `index.html` between `/*WORDS_EN_START*/` and `/*WORDS_EN_END*/` (keyed by internal category ids) — keep both in sync.
- `words_en_review.md`: translator's notes from the first pass. It predates the review fixes, so some chosen English names there are outdated; the JSON/`index.html` are the source of truth.
- Hymns (`찬양 제목` / `hymns`) are NOT index-aligned with the Korean list any more: the English list was rebuilt from well-known English hymns and worship songs (100 entries). The other categories are still positionally aligned with the Korean arrays, except for the explicit replacements listed in the review.
- Numbers followed by a space inside a word (e.g. `1 Samuel`, `3,000 Baptized`) use a non-breaking space (` `) so the number never wraps onto its own line.
- The internal mode id `fool` is kept; its English label is "Undercover".
