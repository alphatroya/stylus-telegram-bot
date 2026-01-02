# Implementation Tasks

## Phase 1: Foundation and Offset Management

### Task 1.1: Create Offset State Manager
- **Description**: Create a new `OffsetManager` struct in `Sources/stylus/Config/` to handle persistent offset storage
- **Deliverables**: 
  - `OffsetManager.swift` with methods to read/write offset state
  - Unit tests for offset persistence, recovery, and atomic updates
- **Validation**: Tests pass showing correct state management under various scenarios
- **Dependencies**: None
- **Effort**: Small (1-2 hours)

### Task 1.2: Add Offset Configuration Path
- **Description**: Extend `ConfigPath` to include offset state file location alongside existing config files  
- **Deliverables**:
  - Updated `ConfigPath.swift` with offset file path resolution
  - Tests for path resolution in different environments
- **Validation**: Offset file stored in same directory as configuration files
- **Dependencies**: Task 1.1
- **Effort**: Small (30 minutes)

### Task 1.3: Implement Offset State Recovery
- **Description**: Add robust error handling for missing, corrupted, or invalid offset state
- **Deliverables**:
  - Graceful fallback to current messages when state is invalid
  - Comprehensive error logging and recovery strategies
  - Tests for various corruption scenarios
- **Validation**: Bot starts successfully even with corrupted/missing state files
- **Dependencies**: Task 1.1, 1.2
- **Effort**: Medium (2-3 hours)

## Phase 2: Telegram Bot Integration 

### Task 2.1: Replace AsyncThrowingStream with Batch Processing
- **Description**: Replace `launch()` method in `TelegramBot.swift` to return processed messages directly instead of streaming
- **Deliverables**:
  - New `fetchAllMessages(startingOffset:)` method using `getUpdatesSync()`
  - Remove streaming-based `launch()` method
  - Update Bot protocol if needed
- **Validation**: Method fetches all pending messages using pagination and returns them as an array
- **Dependencies**: Task 1.1-1.3 (offset management)
- **Effort**: Medium (2-3 hours)

### Task 2.2: Implement Pagination Logic
- **Description**: Add comprehensive pagination to fetch all messages until Telegram returns empty result
- **Deliverables**:
  - Pagination loop that continues until no more messages
  - Proper offset tracking between API calls
  - Configurable batch size with sensible defaults
- **Validation**: Successfully processes large message queues (100+ messages) without duplication
- **Dependencies**: Task 2.1
- **Effort**: Medium (2-3 hours)

### Task 2.3: Add Comprehensive Error Handling
- **Description**: Replace infinite retry loops with proper error handling and meaningful exit codes
- **Deliverables**:
  - Specific error types for different failure scenarios
  - Retry logic with limits for transient failures
  - Clear error messaging and appropriate exit codes
- **Validation**: Bot handles API errors gracefully and exits with proper status codes
- **Dependencies**: Task 2.1, 2.2  
- **Effort**: Medium (1-2 hours)

## Phase 3: App Execution Model

### Task 3.1: Modify App.run() for Finite Execution
- **Description**: Replace infinite message stream processing with finite batch processing in `App.swift`
- **Deliverables**:
  - Updated `App.run()` method that processes finite message arrays
  - Remove `fatalError` when stream terminates
  - Add proper logging for start, progress, and completion
- **Validation**: App processes all messages and exits cleanly with status 0
- **Dependencies**: Task 2.1-2.3 (bot integration changes)
- **Effort**: Small (1 hour)

### Task 3.2: Integrate Offset State Management
- **Description**: Connect offset state management with message processing in App
- **Deliverables**:
  - Read offset state on startup
  - Update offset state after successful message processing
  - Handle offset state errors gracefully
- **Validation**: Offset is properly persisted between runs, no message duplication
- **Dependencies**: Task 3.1, all Phase 1 tasks
- **Effort**: Small (1 hour)

### Task 3.3: Add Execution Logging and Metrics
- **Description**: Add comprehensive logging to provide visibility into one-shot execution
- **Deliverables**:
  - Startup logging with configuration details
  - Progress logging during message processing
  - Summary logging with message counts and execution time
  - Error logging with actionable information
- **Validation**: Logs provide clear insight into execution progress and results
- **Dependencies**: Task 3.1, 3.2
- **Effort**: Small (30 minutes)

## Phase 4: Testing and Validation

### Task 4.1: Update Unit Tests
- **Description**: Update existing tests to work with new execution model and add tests for offset management
- **Deliverables**:
  - Updated `AppTests.swift` for finite execution model
  - New tests for offset state management scenarios  
  - Updated `TelegramBotTests` if Bot protocol changes
- **Validation**: All tests pass with >90% code coverage on new functionality
- **Dependencies**: All previous tasks
- **Effort**: Medium (2-3 hours)

### Task 4.2: Integration Testing
- **Description**: Create comprehensive integration tests for end-to-end one-shot execution
- **Deliverables**:
  - Tests for various message queue scenarios (empty, single, large batch)
  - Tests for offset state persistence across multiple runs
  - Tests for error scenarios and recovery
- **Validation**: Integration tests demonstrate complete functionality
- **Dependencies**: Task 4.1
- **Effort**: Medium (2-3 hours)

### Task 4.3: Manual Testing and Documentation Update
- **Description**: Manual testing with real Telegram bot and update any relevant documentation
- **Deliverables**:
  - Manual test results with various message scenarios
  - Updated README if execution model changes affect usage
  - Performance comparison with previous polling model
- **Validation**: Manual testing confirms expected behavior in real environment
- **Dependencies**: Task 4.2
- **Effort**: Small (1 hour)

## Execution Notes

### Parallelizable Work
- Phase 1 tasks (1.1-1.3) can be developed independently
- Phase 4 tasks (4.1-4.3) can be executed in parallel once Phase 3 is complete

### Critical Path
Phase 1 → Phase 2 → Phase 3 → Phase 4

### Risk Mitigation
- Start with comprehensive unit tests for offset management (Phase 1) to catch edge cases early
- Implement thorough error handling in Phase 2 to prevent data loss
- Use feature flags or configuration if rollback capability is needed during transition

### Definition of Done
- All unit and integration tests pass
- Manual testing confirms correct behavior with real Telegram API
- No message duplication or loss in any test scenario
- Clean exit with appropriate status codes in all scenarios
- Comprehensive logging provides operational visibility