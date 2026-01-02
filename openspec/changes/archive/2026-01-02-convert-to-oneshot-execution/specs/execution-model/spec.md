# Execution Model Specification

## MODIFIED Requirements

### Requirement: One-Shot Message Processing
The bot MUST execute as a finite process that fetches all pending messages, processes them, and exits cleanly rather than running as an infinite polling loop.

#### Scenario: Complete message batch processing
- GIVEN the bot is started
- AND there are pending messages in the Telegram API queue
- WHEN the bot runs
- THEN it MUST fetch all pending messages using pagination
- AND process each message in chronological order
- AND exit with status code 0 when complete
- AND NOT enter any infinite loops

#### Scenario: Empty message queue handling
- GIVEN the bot is started  
- AND there are no pending messages in the Telegram API queue
- WHEN the bot runs
- THEN it MUST detect the empty queue immediately
- AND exit with status code 0 without waiting
- AND log that no messages were processed

### Requirement: Pagination-Based Message Fetching
The bot MUST use the TelegramBotSDK `getUpdatesSync()` method with offset-based pagination to fetch messages in batches rather than using the streaming `nextUpdateSync()` approach.

#### Scenario: Multi-batch message fetching
- GIVEN there are 150 pending messages
- AND the batch limit is 100 messages
- WHEN the bot fetches messages
- THEN it MUST make at least 2 API calls
- AND fetch all 150 messages without duplication
- AND process them in correct chronological order
- AND stop when Telegram returns an empty result

#### Scenario: Offset tracking during pagination
- GIVEN the bot is fetching messages with pagination
- WHEN each batch is processed
- THEN the offset MUST be updated to the next unprocessed message ID
- AND subsequent API calls MUST use the updated offset
- AND no messages MUST be processed more than once

### Requirement: Clean Exit Behavior
The bot MUST exit with appropriate status codes and clear logging rather than running indefinitely or terminating unexpectedly.

#### Scenario: Successful completion
- GIVEN the bot has processed all pending messages
- WHEN processing is complete
- THEN it MUST exit with status code 0
- AND log the number of messages processed
- AND NOT throw fatal errors or exceptions

#### Scenario: Error handling during execution
- GIVEN an error occurs during message processing
- WHEN the error is not recoverable
- THEN the bot MUST exit with a non-zero status code
- AND log the error details clearly
- AND NOT enter infinite retry loops

## REMOVED Requirements

- **Infinite Polling Loop**: The bot no longer maintains an infinite polling loop using `AsyncThrowingStream` and continuous `nextUpdateSync()` calls.

- **Fatal Error on Stream Termination**: The bot no longer uses `fatalError("Bot stream terminated unexpectedly")` when the message stream ends, as streams are replaced with finite batch processing.