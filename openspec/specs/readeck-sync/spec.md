## ADDED Requirements

### Requirement: Readeck sync mode activation
The system SHALL activate Readeck sync mode when the `--readeck` CLI flag is passed. When no flag is provided, the system SHALL run in the default Telegram mode.

#### Scenario: Running with --readeck flag
- **WHEN** the CLI is invoked with `--readeck` argument
- **THEN** the system SHALL fetch bookmarks from Readeck instead of processing Telegram messages

#### Scenario: Running without flag
- **WHEN** the CLI is invoked without `--readeck`
- **THEN** the system SHALL process Telegram messages as it does currently

### Requirement: Readeck configuration
The system SHALL read `readeckEndpoint` and `readeckApiToken` from the YAML config file. Both fields SHALL be required when running in Readeck mode.

#### Scenario: Valid Readeck config present
- **WHEN** `--readeck` is passed and config contains `readeckEndpoint` and `readeckApiToken`
- **THEN** the system SHALL proceed with Readeck sync

#### Scenario: Missing Readeck config
- **WHEN** `--readeck` is passed but `readeckEndpoint` or `readeckApiToken` is missing from config
- **THEN** the system SHALL exit with a descriptive error message

### Requirement: Incremental bookmark sync
The system SHALL fetch only bookmarks that have been created or updated since the last successful sync by calling `GET /bookmarks/sync?since=<timestamp>` on the Readeck API.

#### Scenario: First sync (no stored timestamp)
- **WHEN** no `readeck_last_fetch.txt` file exists
- **THEN** the system SHALL fetch all bookmarks from the Readeck instance (sync without `since` parameter)

#### Scenario: Subsequent sync (stored timestamp exists)
- **WHEN** `readeck_last_fetch.txt` contains a valid ISO 8601 timestamp
- **THEN** the system SHALL call `/bookmarks/sync?since=<stored_timestamp>` and only process changed bookmarks

#### Scenario: Sync response contains updates
- **WHEN** the sync endpoint returns entries with `type: "update"`
- **THEN** the system SHALL fetch full bookmark details for each entry via `GET /bookmarks/{id}`

#### Scenario: Sync response contains deletions
- **WHEN** the sync endpoint returns entries with `type: "delete"`
- **THEN** the system SHALL skip those entries (no action needed)

### Requirement: Last fetch timestamp persistence
The system SHALL store the timestamp of the most recent sync entry (from the sync response's `time` field) in `readeck_last_fetch.txt` using ISO 8601 format. The file SHALL be written atomically in the same directory as the config file.

#### Scenario: Successful sync completes
- **WHEN** all bookmarks from a sync have been processed and written to journal files
- **THEN** the system SHALL update `readeck_last_fetch.txt` with the latest `time` value from the sync response

#### Scenario: Sync fails partially
- **WHEN** an error occurs during bookmark processing
- **THEN** the system SHALL NOT update `readeck_last_fetch.txt` (so the next run retries the same window)

### Requirement: Bookmark to journal entry transformation
The system SHALL transform each Readeck bookmark into a markdown journal entry line appended to the daily journal file corresponding to the bookmark's creation date. Every entry SHALL include the `#from-readeck` source tag. Readeck labels SHALL be converted to individual `#tag` entries placed after the link. The `#stylus-inbox` tag SHALL be appended last.

#### Scenario: Bookmark with title and labels
- **WHEN** a bookmark has title "Swift Concurrency Guide", URL "https://example.com/swift", labels ["programming", "swift"], and was created at 2025-06-15T14:30:00Z
- **THEN** the system SHALL append to `2025_06_15.md`: `- **14:30** [Swift Concurrency Guide](https://example.com/swift) #from-readeck #programming #swift #stylus-inbox\n`

#### Scenario: Bookmark with no labels
- **WHEN** a bookmark has no labels
- **THEN** the system SHALL append the entry with `#from-readeck #stylus-inbox` tags

#### Scenario: Bookmark with no title
- **WHEN** a bookmark has an empty title
- **THEN** the system SHALL use the URL as the link text and still include `#from-readeck`

#### Scenario: Source tag always present
- **WHEN** any bookmark is transformed into a journal entry
- **THEN** the entry SHALL include the `#from-readeck` tag to identify the data source

#### Scenario: Labels as separate tags
- **WHEN** a bookmark has labels ["tech", "ai", "research"]
- **THEN** each label SHALL appear as a separate tag: `#tech #ai #research`

### Requirement: Readeck API authentication
The system SHALL authenticate all Readeck API requests using Bearer token authentication via the `Authorization` header.

#### Scenario: API request with valid token
- **WHEN** a request is made to the Readeck API
- **THEN** the system SHALL include `Authorization: Bearer <readeckApiToken>` header

#### Scenario: API returns 401 Unauthorized
- **WHEN** the Readeck API responds with HTTP 401
- **THEN** the system SHALL exit with an error indicating invalid or expired API token

### Requirement: Journal directory structure compatibility
The system SHALL write bookmark journal entries to the same `journals/` subdirectory within the knowledge base, using the same date-based filename pattern (`yyyy_MM_dd.md`) as Telegram message processing.

#### Scenario: Journal file already exists
- **WHEN** a journal file for the bookmark's date already exists (possibly from Telegram entries)
- **THEN** the system SHALL append the bookmark entry to the existing file

#### Scenario: Journal file does not exist
- **WHEN** no journal file exists for the bookmark's date
- **THEN** the system SHALL create a new file with the bookmark entry
