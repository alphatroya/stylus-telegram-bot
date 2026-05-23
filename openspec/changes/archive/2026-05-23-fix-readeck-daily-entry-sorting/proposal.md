## Why

Articles saved in daily journal files via Readeck sync are not sorted by time. When multiple bookmarks for the same day are fetched, they are appended in the order the API returns them — not chronologically. This results in entries like 18:55 appearing before 9:05 within the same journal file, making daily logs disorganized and hard to read.

## What Changes

- Sort journal entries by their timestamp before writing them to daily journal files
- Group entries by journal file (day), then sort within each group by time
- Preserve existing content in journal files (append sorted entries at the end)

## Capabilities

### New Capabilities

- `readeck-entry-sorting`: Ensures bookmark entries targeting the same daily journal file are sorted by time (HH:mm) before being written

### Modified Capabilities

- `readeck-sync`: The sync flow requirement changes from "process one-by-one and append" to "collect, group, sort, then write" to guarantee chronological order within each day

## Impact

- `ReadeckSyncRunner` — must batch-transform bookmarks, group by journal file, sort within each group, then write
- `BookmarkJournalTransformer` — no changes (already produces time-prefixed lines)
- `JournalWriter` — may need a method to write multiple lines at once instead of one-by-one appends
- Tests for `ReadeckSyncRunner` — need new test cases for sorting behavior
