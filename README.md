# Cableform

Turn text or files into **paper telegrams** — the filled-out form you would have held in your hand, not Morse code.

## What it does

1. Type a message or open / drop any text file (or a `.cblf` document).
2. Fill the blank: company line, To, From, Office, date; Paid/Collect check is optional.
3. Optionally apply wire-desk wording (ALL CAPS, `STOP`, short abbreviations) for the body only.
4. Preview the **paper form** live.
5. If you opened a **`.cblf`**, edit and **Save** (⌘S) to overwrite that file. **Save As…** (⌘⇧S) writes a new document.
6. Export as:
   - **Plain text** (`.txt`) — readable telegram transcript  
   - **Paper form** (`.png`) — cream blank with rules, stub, and message  
   - **Cableform** (`.cblf`) — custom binary paper-telegram document (see `FORMAT.md`)

## Requirements

- macOS 13+
- Swift toolchain (Xcode or Command Line Tools)

## Build & run

```bash
./build-app.sh
```

Use `./build-app.sh --no-launch` to build without opening the app.

## Notes

This app is only about the **paper output** of a telegraph message (the form and its exports). It does not generate Morse or audio.
