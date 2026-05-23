## Context

The `ReadeckSyncRunner` processes bookmarks one-by-one in a loop, immediately appending each transformed entry to its daily journal file. The Readeck `/bookmarks/sync` API returns entries ordered by sync time (when the change was detected), not by bookmark creation time. This means bookmarks created at 9:05 but synced after one created at 18:55 get written in the wrong order within the same day's journal file.

Current flow: `fetch sync entries → for each: fetch details → transform → append to file`

This guarantees chronological order within a single run only if the API happens to return entries sorted by creation time — which it does not.

## Goals / Non-Goals

**Goals:**
- Guarantee that entries within each daily journal file are sorted by time (HH:mm) ascending
- Maintain backward compatibility with existing journal file content (append-only, don't rewrite existing lines)
- Keep the change minimal — no architectural overhaul

**Non-Goals:**
- Sorting entries across different days (each day's file is independent)
- Re-sorting or rewriting previously written entries in journal files
- Changing the `BookmarkJournalTransformer` output format
- Handling duplicate detection (existing entries already in the file)

## Decisions

### Decision 1: Batch-transform, group-by-day, sort, then write

Instead of processing bookmarks one-by-one, collect all transformed entries first, group them by journal file name (day), sort each group by time, then write each group.

**Rationale**: This is the simplest correct approach. It requires no changes to `BookmarkJournalTransformer` or `JournalWriter`'s existing methods — only restructuring the loop in `ReadeckSyncRunner.run()`.

**Alternative considered**: Sort by parsed creation date instead of the `HH:mm` prefix in the entry line. Rejected because the transformer already parses the date and the entry line's `**HH:mm**` prefix is directly derived from it — sorting by the parsed `Date` is equivalent but requires carrying the date through the pipeline. Sorting the `(fileName, entryLine)` tuples by `entryLine` string comparison is sufficient since `HH:mm` is zero-padded and appears at a fixed position.

### Decision 2: Sort by parsed Date, not by entry line string

Carry the parsed `Date` from the transformer and use it as the sort key. This is more robust than string comparison.

**Rationale**: The `BookmarkJournalTransformer.transform()` already parses the ISO 8601 date. We should modify it to also return the parsed `Date` so the runner can sort by it. This avoids fragile string-based sorting.

### Decision 3: Use a new JournalWriter method to append multiple sorted entries

Add a method like `appendToJournalFile(at:contents:)` that takes an array of strings and appends them all at once. This is cleaner than calling the single-entry method in a loop.

**Rationale**: Keeps the writing atomic per day — all entries for a given day are written together.

## Risks / Trade-offs

- **[Memory]** All transformed entries are held in memory before writing → Negligible risk; sync batches are typically small (tens to hundreds of entries)
- **[Partial write]** If writing fails for one day's file, some days may already be written → Existing behavior (timestamp only updates after full success) mitigates this — the next run will re-process the same window
- **[Breaking change to transformer API]** `transform()` return type changes → Internal API only; no public consumers
