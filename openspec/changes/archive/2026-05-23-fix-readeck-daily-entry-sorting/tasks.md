## 1. Update BookmarkJournalTransformer

- [x] 1.1 Modify `transform()` return type to include the parsed `Date` — change from `(journalFileName: String, entryLine: String)` to `(journalFileName: String, entryLine: String, date: Date)`, returning the already-parsed date from `parseDate()`
- [x] 1.2 Update `BookmarkJournalTransformerTests` to verify the new `date` field is returned correctly for all existing test cases

## 2. Update JournalWriter

- [x] 2.1 Add `appendToJournalFile(at:contents:)` method to `JournalWriter` that accepts an array of strings and appends them all to the journal file in order

## 3. Refactor ReadeckSyncRunner for batch-sort-write

- [x] 3.1 Replace the one-by-one processing loop with a batch approach: collect all `(fileName, entryLine, date)` tuples into an array first
- [x] 3.2 Group the collected tuples by `journalFileName` (day)
- [x] 3.3 Sort each group by `date` ascending
- [x] 3.4 Write each sorted group using the new `appendToJournalFile(at:contents:)` method
- [x] 3.5 Update `ReadeckSyncRunnerTests` with test cases covering: multiple entries same day unsorted → sorted output, multiple days → independent sorting, single entry → no reordering

## 4. Format and verify

- [x] 4.1 Run `swiftformat .` to ensure code style
- [x] 4.2 Run `swift test` and ensure all existing and new tests pass
