# Changelog

All notable changes to **Cableform** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

## [1.0.5] - 2026-08-07

### Added

- **Unsaved-change tracking** against the last loaded/saved/cleared snapshot
- Confirm before **Clear**, **Open**, drop, or Finder open when edits would be lost (Save / Don’t Save / Cancel)
- Window title shows `•` and the system document-edited indicator while dirty
- Sidebar hint and Save button enable state reflect dirty status
- Exporting `.txt` / `.png` does not clear dirty state (only saving `.cblf` does)

## [1.0.4] - 2026-08-07

### Added

- **Save** overwrites the open `.cblf` after edit (⌘S); no export panel required
- **Save As…** (⌘⇧S) writes a new `.cblf` and makes it the active document
- Document section shows the open filename; text imports do not bind a save target
- Security-scoped access is held for the open document so re-save works after Open/drop

## [1.0.3] - 2026-08-07

### Fixed

- `.cblf` metadata `appVersion` is taken from `CFBundleShortVersionString` instead of a hardcoded `1.0.0`
- Invalid UTF-8 in a structurally valid `.cblf` text field (or metadata) is rejected as a corrupt document instead of becoming an empty string

## [1.0.2] - 2026-08-07

### Fixed

- **`.cblf` documents now load reliably** — open path no longer depends on Launch Services binding the custom UTI to the file
- Open dialog accepts **any file** (starts in Downloads) so `.cblf` files are always selectable
- Decode/apply path force-refreshes the form and paper preview after open (TextEditor / bindings no longer stick on empty state)
- Loading a document no longer overwrites the saved paper body via live wire-style rewrite mid-apply
- Drop handler accepts more drop payload shapes (`URL`, `Data`, path `String`)
- Finder / Dock / `open -a` file open works via app-delegate bridge (`OpenBridge`)
- Errors surface in an alert as well as the status capsule

### Added

- **⌘O** (File → Open…) to open text or `.cblf` files
- Security-scoped access and symlink resolution when reading opened URLs
- `LSSupportsOpeningDocumentsInPlace` for document open behavior

## [1.0.1] - 2026-08-07

### Fixed

- **Double extensions on save** (e.g. `telegram.cblf.cblf`) — save panel name field is extension-free; final path is normalized to a single managed extension
- Binary `.cblf` read/write is **alignment-safe** (byte-wise little-endian I/O instead of unaligned `load(as:)`)
- Open detects documents by **magic bytes** (`CBLF`), including legacy double-extension filenames

### Added

- Exported UTI `com.cableform.cblf` in Info.plist for the Cableform document type

## [1.0.0] - 2026-08-07

### Added

- Initial release: turn text or files into **paper telegrams** (not Morse)
- Live cream paper form preview (banner, stub perforations, ruled message area)
- Header fields: company line, To, From, Office, date filed, word count
- Optional **Paid / Collect** check (off by default; omitted from paper when disabled)
- Optional **wire-desk wording** for the body (caps, `STOP`, abbreviations)
- Open text files or drop them onto the paper preview
- Export as:
  - **Plain text** (`.txt`)
  - **Paper form image** (`.png`)
  - **Cableform document** (`.cblf` — custom binary format; see `FORMAT.md`)
- macOS app bundle build via `./build-app.sh`
- App icon and README
