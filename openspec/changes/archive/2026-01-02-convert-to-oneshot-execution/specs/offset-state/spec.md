# Offset State Management Specification

## ADDED Requirements

### Requirement: Persistent Offset Storage
The bot MUST maintain persistent storage of the last processed Telegram update ID to prevent message duplication or loss between executions.

#### Scenario: Offset persistence after successful run
- GIVEN the bot processes messages with update IDs [100, 101, 102]
- WHEN the bot completes successfully
- THEN it MUST store offset 103 (next unprocessed ID) to persistent storage
- AND the storage MUST survive bot restarts
- AND be located in the config folder alongside existing configuration

#### Scenario: Offset restoration on startup
- GIVEN the stored offset is 103
- WHEN the bot starts up
- THEN it MUST read the offset from persistent storage
- AND begin fetching messages starting from update ID 103
- AND NOT reprocess messages with IDs 100, 101, 102

### Requirement: State File Management
The bot MUST store offset state in a dedicated file within the config folder using a simple, reliable format.

#### Scenario: State file location and naming
- GIVEN the bot needs to store offset state
- WHEN determining the storage location
- THEN it MUST use the same directory as existing configuration files
- AND name the file `telegram_offset.txt` or similar descriptive name
- AND use a simple text format containing only the numeric offset

#### Scenario: State file creation
- GIVEN no offset state file exists (first run)
- WHEN the bot starts up
- THEN it MUST start from current messages (skip old ones)
- AND create the offset state file when the first batch is processed
- AND ensure proper file permissions for read/write access

### Requirement: State Recovery and Error Handling
The bot MUST handle missing, corrupted, or invalid offset state gracefully without losing functionality.

#### Scenario: Missing state file recovery
- GIVEN the offset state file does not exist
- WHEN the bot starts up
- THEN it MUST start processing from current messages
- AND NOT attempt to process historical messages
- AND create a new offset state file with the current offset

#### Scenario: Corrupted state file recovery
- GIVEN the offset state file contains invalid data (non-numeric, corrupted)
- WHEN the bot attempts to read the offset
- THEN it MUST log a warning about the corrupted state
- AND start from current messages as if no state file exists
- AND overwrite the corrupted file with valid state

#### Scenario: State file write failure handling
- GIVEN the bot has processed new messages
- WHEN attempting to update the offset state file fails (permissions, disk space)
- THEN it MUST log an error about the write failure
- AND continue processing messages normally
- AND attempt to write state again on the next successful batch

### Requirement: Atomic State Updates
The bot MUST ensure offset state updates are atomic to prevent partial writes that could lead to message duplication.

#### Scenario: Atomic offset update
- GIVEN the bot has processed a batch of messages
- WHEN updating the offset state
- THEN it MUST write to a temporary file first
- AND atomically move/rename to the final state file
- AND ensure the update is complete before processing the next batch

#### Scenario: Crash during state update
- GIVEN the bot crashes during offset state update
- WHEN the bot restarts
- THEN it MUST detect incomplete state updates
- AND use the last known good offset
- AND recover without message duplication or loss