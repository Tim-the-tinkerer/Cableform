# Cableform Document Format (`.cblf`)

Custom paper-telegram container used by **Cableform**.

## Layout (little-endian)

| Offset | Size | Field |
|--------|------|--------|
| 0 | 4 | Magic `CBLF` |
| 4 | 2 | Version (`1`) |
| 6 | 2 | Flags (bit 0 = wire-style body applied) |
| 8 | 8 | Created (Unix seconds, `i64`) |
| 16 | 4 | `toLen` |
| 20 | 4 | `fromLen` |
| 24 | 4 | `officeLen` |
| 28 | 4 | `bodyLen` |
| 32 | 4 | `sourceLen` |
| 36 | 4 | `metaLen` |
| 40 | … | UTF-8: to, from, office, body, source |
| … | … | UTF-8 JSON metadata |

## Metadata JSON keys

- `paidCollect` — optional; `"PAID"` or `"COLLECT"` when present; omit key to hide CHECK on paper
- `wordCount` — stringified integer
- `company` — form header line
- `notes` — freeform
- `app` — always `"Cableform"`
- `appVersion` — marketing version from the writing app’s `CFBundleShortVersionString`
- `wireMode` — `"plain"`, `"desk"`, or `"period"` (period-accurate commercial telegram wording)

Flags (u16): bit 0 = any wire rewrite; bit 1 = period mode (legacy readers may ignore bit 1).

Body text is the paper message as displayed (after optional wire styling).
Source text is the original unprocessed input.

Text fields (`to`, `from`, `office`, `body`, `source`, and metadata JSON) must be valid UTF-8.
Invalid UTF-8 is treated as a corrupt document and rejected on open.
