## ADDED Requirements

### Requirement: Journal entries sorted by time within each day
The system SHALL sort all bookmark journal entries targeting the same daily journal file by their creation time (ascending) before writing them to disk.

#### Scenario: Multiple bookmarks on the same day arrive unsorted
- **WHEN** a sync batch contains bookmarks for the same day with creation times 18:55, 09:05, and 14:30
- **THEN** the system SHALL write them to the journal file in order: 09:05, 14:30, 18:55

#### Scenario: Single bookmark for a day
- **WHEN** a sync batch contains exactly one bookmark for a given day
- **THEN** the system SHALL write that single entry without any sorting overhead

#### Scenario: Bookmarks spanning multiple days
- **WHEN** a sync batch contains bookmarks for 2025-06-15 and 2025-06-16
- **THEN** the system SHALL independently sort and write entries for each day, preserving chronological order within each day's file

### Requirement: Transformer returns parsed date for sorting
The `BookmarkJournalTransformer.transform()` method SHALL return the parsed `Date` alongside the journal file name and entry line, so that callers can use it as a sort key.

#### Scenario: Transform output includes date
- **WHEN** `transform()` is called with a bookmark created at `2025-06-15T14:30:00Z`
- **THEN** the return value SHALL include the parsed `Date` equivalent to `2025-06-15T14:30:00Z`
