# Implementation Tasks

## Task Breakdown

### 1. Create MessageHandler Protocol and Implementation
- [x] Define `MessageHandler` protocol in `Sources/stylus/Message/MessageHandler.swift`
- [x] Define protocol methods for all current handle functions:
  - `handleJustTextMessage(text:timeString:filePath:originalSender:)`
  - `handleImageMessage(fileId:caption:timeString:filePath:originalSender:)`
  - `handleDocumentMessage(fileId:fileName:caption:timeString:filePath:originalSender:)`
  - `handleMessageType(_:timeString:filePath:originalSender:)`
  - `saveFileWithUniqueFilename(data:baseFileName:assetsURL:)`
- [x] Create `DefaultMessageHandler` struct implementing the protocol
- [x] Move all handler logic from App.swift to DefaultMessageHandler

### 2. Extract Supporting Types and Functions  
- [x] Move `FileNameGenerationError` enum to Message module
- [x] Move `formatMediaEntry` helper function to MessageHandler implementation
- [x] Move file handling constants (`uuidSuffixLength`, `maxFileNameRetries`) to MessageHandler

### 3. Update App.swift Integration
- [x] Add `messageHandler` property to App struct with `MessageHandler` protocol type
- [x] Update App initializer to accept MessageHandler dependency
- [x] Replace direct handler calls in `processMessage` with messageHandler calls
- [x] Remove all extracted handler functions and supporting code from App.swift

### 4. Update Dependency Injection
- [x] Modify App initialization in main entry point to inject DefaultMessageHandler
- [x] Ensure MessageHandler receives necessary dependencies (config, journalWriter, linkProcessor, etc.)
- [x] Update test setup to use protocol for mocking

### 5. Update Tests
- [x] Move tests for handler functions from `AppTests.swift` to new `MessageHandlerTests.swift`
- [x] Create mock MessageHandler implementation for testing App orchestration
- [x] Update existing tests to work with new structure
- [x] Ensure all tests pass with refactored code

### 6. Validate Integration
- [x] Run full test suite to ensure no regressions
- [x] Verify bot functionality works end-to-end
- [x] Check that all message types are handled correctly
- [x] Validate file operations and asset handling still work

## Validation Criteria
- All existing tests pass
- No changes to external behavior or API
- Code coverage maintained or improved
- SwiftFormat passes on all modified files
- Full integration test passes (bot can process all message types)

## Dependencies
- Tasks 1-3 can be worked on in parallel
- Task 4 depends on completion of tasks 1-3
- Tasks 5-6 depend on completion of task 4

## Estimated Effort
- **Task 1**: High (core logic extraction)
- **Task 2**: Low (moving supporting code)
- **Task 3**: Medium (App integration updates)
- **Task 4**: Low (dependency injection)
- **Task 5**: Medium (test refactoring)
- **Task 6**: Low (validation)

Total: 2-3 hours of focused development work