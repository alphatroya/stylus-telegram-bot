## Why

When the Readeck sync or Telegram bot runs multiple times (retries, re-deploys, crashed mid-run), the same entry can be appended to a daily journal file more than once. The current `appendToJournalFile` logic always appends without checking whether the content already exists in the target file. This produces duplicate lines in daily logs that have to be cleaned up manually.

## What Changes

- Before appending a journal entry line, check whether an identical line already exists in the target daily journal file
- Skip writing lines that are already present in the file
- Log a message when a duplicate is detected and skipped, so operators can see deduplication is working

## Capabilities

### New Capabilities
- `duplicate-journal-entry-detection`: Detect and skip journal entry lines that already exist in a daily journal file before appending

### Modified Capabilities
- `readeck-sync`: The ReadeckSyncRunner will benefit from duplicate detection when re-processing bookmarks after a partial or failed sync

## Impact

- `JournalWriter` — add a duplicate-check path before appending content
- `ReadeckSyncRunner` — relies on the updated JournalWriter behavior, no structural changes needed
- `MessageHandler` / `App` — Telegram message handling also benefits from the same deduplication automatically
- No API or dependency changes required
