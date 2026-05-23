## Context

The Stylus Telegram bot writes journal entries to daily markdown files (`yyyy_MM_dd.md`) in a `journals/` directory. Two entry paths produce these lines:

1. **Telegram messages** — `App.processMessage()` → `MessageHandler` → `JournalWriter.appendToJournalFile()`
2. **Readeck sync** — `ReadeckSyncRunner.run()` → `BookmarkJournalTransformer` → `JournalWriter.appendToJournalFile()`

`JournalWriter.appendToJournalFile()` always appends content without checking whether the line already exists in the file. If a sync run or bot invocation is retried (partial failure, re-deploy, manual re-run), the same entry line gets written again, producing duplicates.

## Goals / Non-Goals

**Goals:**
- Prevent duplicate journal entry lines from being written to daily journal files
- Deduplication should work for both Telegram message entries and Readeck sync entries
- Maintain existing append behavior for genuinely new entries
- Provide visibility into deduplication via log output

**Non-Goals:**
- Removing existing duplicates already present in files (one-time cleanup)
- Deduplication across different daily journal files (entries are scoped to a single day file)
- Semantic deduplication (e.g., detecting that two differently formatted lines refer to the same URL) — only exact string matching

## Decisions

### 1. Check for duplicates at the `JournalWriter` level

**Decision**: Add a duplicate check inside `appendToJournalFile(at:content:)` before writing.

**Rationale**: Both entry paths (Telegram and Readeck) already funnel through `JournalWriter.appendToJournalFile()`. Placing the check here deduplicates both sources with a single code change. Alternatives considered:

- *Check at caller level (App / ReadeckSyncRunner)*: Would require duplicating the dedup logic in two places, and any future entry path would need to remember to include it.
- *Post-processing dedup script*: Requires a separate tool and manual execution; doesn't prevent duplicates in real-time.

### 2. Exact string matching on the entry line

**Decision**: Compare the full content string being appended against each existing line in the file.

**Rationale**: Journal entries are deterministic — the same source data always produces the same line. Exact string matching is simple, fast (daily files are small), and has zero false positives. No need for fuzzy or URL-based matching.

### 3. Read file contents once per `appendToJournalFile` call

**Decision**: For single-content calls, read the file and check if the content already exists before appending. For batch calls (`appendToJournalFile(at:contents:)`), read the file once, filter out duplicates, and write only new lines.

**Rationale**: Reading the file once minimizes I/O. Daily journal files are typically small (< 100 lines), so in-memory comparison is negligible.

## Risks / Trade-offs

- **[Performance]** Daily journal files could theoretically grow large over time → Mitigation: Files are per-day, so growth is naturally bounded. A single day rarely exceeds a few hundred entries.
- **[Edge case: partial line match]** If an entry line is a substring of another line, the exact match avoids false positives → No mitigation needed; exact line matching handles this correctly.
- **[Log noise]** Printing a message for every skipped duplicate could be verbose in bulk sync → Mitigation: Log once per duplicate with the entry snippet, keep it brief.
