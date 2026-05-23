## ADDED Requirements

### Requirement: Duplicate entry detection before append
`JournalWriter.appendToJournalFile(at:content:)` SHALL check whether the content string already exists as a line in the target file before writing. If the exact content string is already present in the file, the system SHALL skip writing it.

#### Scenario: Content already exists in file
- **WHEN** `appendToJournalFile` is called with content `- **14:30** [Title](url) #from-readeck #stylus-inbox\n` and the file already contains a line matching that exact string
- **THEN** the system SHALL NOT write the content and SHALL NOT modify the file

#### Scenario: Content does not exist in file
- **WHEN** `appendToJournalFile` is called with content that does not match any existing line in the file
- **THEN** the system SHALL append the content as it does currently

#### Scenario: Target file does not exist
- **WHEN** `appendToJournalFile` is called for a file path that does not exist
- **THEN** the system SHALL create the file and write the content (no dedup check needed)

#### Scenario: Target file exists but is empty
- **WHEN** `appendToJournalFile` is called for an existing empty file
- **THEN** the system SHALL append the content (no duplicate possible in an empty file)

### Requirement: Batch duplicate filtering
`JournalWriter.appendToJournalFile(at:contents:)` SHALL filter out any entries from the `contents` array that already exist in the target file before writing. Only entries not already present SHALL be appended.

#### Scenario: Batch call with some duplicates
- **WHEN** `appendToJournalFile(at:contents:)` is called with three entries where two already exist in the file and one is new
- **THEN** the system SHALL append only the one new entry and skip the two duplicates

#### Scenario: Batch call with all duplicates
- **WHEN** `appendToJournalFile(at:contents:)` is called with entries that all already exist in the file
- **THEN** the system SHALL NOT modify the file at all

#### Scenario: Batch call with no duplicates
- **WHEN** `appendToJournalFile(at:contents:)` is called with entries where none exist in the file
- **THEN** the system SHALL append all entries

### Requirement: Duplicate skip logging
When a duplicate entry is detected and skipped, the system SHALL print a log message indicating that a duplicate was skipped, including the file path. The log SHALL use a distinct emoji or prefix for easy identification in logs.

#### Scenario: Single duplicate skipped
- **WHEN** a single content line is detected as a duplicate and skipped
- **THEN** the system SHALL print a log message like `🔁 Skipped duplicate entry in <filename>`

#### Scenario: Multiple duplicates in batch
- **WHEN** multiple duplicate entries are filtered out during a batch append
- **THEN** the system SHALL print a log message indicating how many duplicates were skipped
