# Convert from Infinite Polling Loop to One-Shot Message Processing

## Change ID
`convert-to-oneshot-execution`

## Summary
Replace the current infinite polling loop architecture with a one-shot execution model that fetches all pending messages using pagination, processes them, and exits cleanly. This transformation enables scheduled execution environments while maintaining all existing functionality.

## Problem Statement
The current bot implementation uses an infinite polling loop (`TelegramBot.swift:41`) that continuously fetches messages via `bot.nextUpdateSync()`. This creates several operational challenges:

1. **Resource consumption**: Long-running process that consumes resources even when idle
2. **Integration complexity**: Difficult to integrate with scheduled execution environments (cron, GitHub Actions, serverless)
3. **Error recovery**: If the process crashes, it requires manual restart
4. **Deployment complexity**: Requires persistent process management

## Proposed Solution
**Complete replacement** of the infinite polling model with a **one-shot execution model** that:
1. Starts up and connects to Telegram API
2. Fetches all pending messages using pagination (no timeout - fetch until empty)
3. Processes each message (journal writing + confirmation)
4. Exits cleanly with appropriate status code

## Benefits
- **Scheduled execution**: Perfect for cron jobs, GitHub Actions, or serverless functions
- **Resource efficiency**: No persistent connections or idle resource consumption
- **Better debugging**: Finite execution with clear logs and exit status
- **Improved reliability**: Each run is independent, better error recovery
- **Simpler deployment**: Stateless execution model

## Architecture Impact
This change affects two core capabilities:

### 1. Execution Model (`execution-model`)
- Replace streaming-based message processing with batch processing
- Modify App.run() to handle finite message sets and clean exit
- Remove infinite loops and blocking operations

### 2. Offset State Management (`offset-state`)
- Add persistent state management for Telegram update offsets
- Store offset in config folder alongside existing configuration
- Handle state corruption and missing state gracefully

## Technical Approach
The solution leverages the existing TelegramBotSDK `getUpdatesSync()` method which supports:
- `offset` parameter for pagination
- `limit` parameter for batch size control
- Returns empty array when no more updates available

Current implementation analysis:
- `nextUpdateSync()` internally uses `getUpdatesSync(offset: nextOffset, limit: defaultUpdatesLimit, timeout: defaultUpdatesTimeout)`
- The SDK already manages offset tracking in `nextOffset` property
- We can build on this existing pagination infrastructure

## Scope and Dependencies
- **In scope**: Complete replacement of execution model, offset state management
- **Out of scope**: Changes to message processing logic, journal writing, or configuration management
- **Dependencies**: None - uses existing TelegramBotSDK capabilities
- **Breaking changes**: Yes - changes fundamental execution model, but maintains all functionality

## Acceptance Criteria
- App processes all pending messages and exits with status 0
- No infinite loops or blocking operations anywhere
- Messages processed in correct chronological order  
- Zero message duplication or loss between runs
- Meaningful error handling with appropriate exit codes
- Clear logging: startup, message count processed, exit status
- Existing journal storage and configuration remain compatible
- Pagination works correctly: continues fetching until Telegram returns empty

## Related Issues
- Addresses GitHub issue #57: "Convert from infinite polling loop to one-shot message processing"

## Implementation Strategy
This change will be implemented in a single phase with careful attention to:
1. Offset state persistence and recovery
2. Comprehensive testing with various message scenarios
3. Proper error handling and exit codes
4. Backwards compatibility for configuration and storage