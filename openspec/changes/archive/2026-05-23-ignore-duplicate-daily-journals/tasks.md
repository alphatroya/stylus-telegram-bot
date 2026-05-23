## 1. Core Deduplication Logic

- [x] 1.1 Add a private `containsDuplicate(at:content:)` method to `JournalWriter` that reads the file, splits into lines, and checks if any line matches the trimmed content string. Returns `true` if a match is found, `false` otherwise (including when the file doesn't exist or is empty).
- [x] 1.2 Update `appendToJournalFile(at:content:)` to call the duplicate check before writing. If duplicate is detected, print `🔁 Skipped duplicate entry in <filename>` and return without modifying the file.
- [x] 1.3 Update `appendToJournalFile(at:contents:)` to read the file once, filter out duplicates from the `contents` array, log how many were skipped, and only write new entries. If all are duplicates, return without modifying the file.

## 2. Tests

- [x] 2.1 Test: single duplicate detected and skipped — append same line twice, verify file contains it only once.
- [x] 2.2 Test: non-duplicate entry appended normally — append two different lines, verify both are present.
- [x] 2.3 Test: file doesn't exist — first append creates the file (no dedup needed).
- [x] 2.4 Test: empty existing file — append to empty file writes the content.
- [x] 2.5 Test: batch with some duplicates — three entries where two already exist, verify only the new one is appended.
- [x] 2.6 Test: batch with all duplicates — all entries already present, verify file is unchanged.
- [x] 2.7 Test: batch with no duplicates — all entries are new, verify all are appended.

## 3. Verification

- [x] 3.1 Run full test suite (`swift test`) and ensure all tests pass including new ones.
- [x] 3.2 Run `swiftformat .` to ensure code style compliance.
