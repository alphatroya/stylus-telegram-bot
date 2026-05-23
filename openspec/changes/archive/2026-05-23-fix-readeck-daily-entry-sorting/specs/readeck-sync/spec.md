## MODIFIED Requirements

### Requirement: Incremental bookmark sync
The system SHALL fetch only bookmarks that have been created or updated since the last successful sync by calling `GET /bookmarks/sync?since=<timestamp>` on the Readeck API. The system SHALL batch-transform all fetched bookmarks, group them by journal file (day), sort each group by creation time ascending, and then write each group to its journal file.

#### Scenario: First sync (no stored timestamp)
- **WHEN** no `readeck_last_fetch.txt` file exists
- **THEN** the system SHALL fetch all bookmarks from the Readeck instance (sync without `since` parameter)

#### Scenario: Subsequent sync (stored timestamp exists)
- **WHEN** `readeck_last_fetch.txt` contains a valid ISO 8601 timestamp
- **THEN** the system SHALL call `/bookmarks/sync?since=<stored_timestamp>` and only process changed bookmarks

#### Scenario: Sync response contains updates
- **WHEN** the sync endpoint returns entries with `type: "update"`
- **THEN** the system SHALL fetch full bookmark details for each entry via `GET /bookmarks/{id}`, transform all of them, group by day, sort each group by creation time, and write sorted entries to journal files

#### Scenario: Sync response contains deletions
- **WHEN** the sync endpoint returns entries with `type: "delete"`
- **THEN** the system SHALL skip those entries (no action needed)

#### Scenario: Entries for same day are sorted chronologically
- **WHEN** multiple bookmarks target the same journal file (same day) and their creation times are unsorted
- **THEN** the system SHALL write them in ascending creation time order

### Requirement: Bookmark to journal entry transformation
The system SHALL transform each Readeck bookmark into a markdown journal entry line appended to the daily journal file corresponding to the bookmark's creation date. Every entry SHALL include the `#from-readeck` source tag. Readeck labels SHALL be converted to individual `#tag` entries placed after the link. The `#stylus-inbox` tag SHALL be appended last. The transform method SHALL also return the parsed creation `Date` for use in sorting.

#### Scenario: Bookmark with title and labels
- **WHEN** a bookmark has title "Swift Concurrency Guide", URL "https://example.com/swift", labels ["programming", "swift"], and was created at 2025-06-15T14:30:00Z
- **THEN** the system SHALL produce for `2025_06_15.md`: `- **14:30** [Swift Concurrency Guide](https://example.com/swift) #from-readeck #programming #swift #stylus-inbox\n` and the parsed Date `2025-06-15T14:30:00Z`

#### Scenario: Bookmark with no labels
- **WHEN** a bookmark has no labels
- **THEN** the system SHALL produce the entry with `#from-readeck #stylus-inbox` tags and the parsed Date

#### Scenario: Bookmark with no title
- **WHEN** a bookmark has an empty title
- **THEN** the system SHALL use the URL as the link text, include `#from-readeck`, and return the parsed Date

#### Scenario: Source tag always present
- **WHEN** any bookmark is transformed into a journal entry
- **THEN** the entry SHALL include the `#from-readeck` tag to identify the data source

#### Scenario: Labels as separate tags
- **WHEN** a bookmark has labels ["tech", "ai", "research"]
- **THEN** each label SHALL appear as a separate tag: `#tech #ai #research`
