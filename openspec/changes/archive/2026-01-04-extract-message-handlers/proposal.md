# Extract Message Handlers from App.swift

## Overview
Extract all message handling functions from `App.swift` into a separate handlers abstraction to improve code organization, testability, and maintainability by following the single responsibility principle.

## Problem Statement
Currently, the `App` struct in `Sources/stylus/Core/App.swift` contains both application orchestration logic and detailed message processing logic mixed together. This violates the single responsibility principle and makes the code harder to maintain and test.

The App struct currently handles:
- Application lifecycle and coordination (`run()` method)
- Message processing dispatch (`processMessage`, `handleMessageType`)
- Specific message type handling (`handleJustTextMessage`, `handleImageMessage`, `handleDocumentMessage`)
- File operations (`saveFileWithUniqueFilename`)
- Formatting utilities (`formatMediaEntry`)

This mixing of concerns makes the App class over 360 lines long and responsible for too many different aspects of the system.

## Proposed Solution
Extract all message handling functions into a dedicated `MessageHandler` protocol and implementation, creating clear separation between:
- **App**: Application orchestration, lifecycle management, and coordination
- **MessageHandler**: Message processing logic, type-specific handling, and formatting

This follows the established architecture pattern in the codebase of using protocols for dependency injection and modular design.

## Benefits
1. **Improved Maintainability**: Cleaner separation of concerns makes code easier to understand and modify
2. **Better Testability**: Message handling logic can be tested independently of application orchestration
3. **Enhanced Modularity**: Follows the project's established pattern of focused, single-responsibility modules
4. **Easier Extension**: New message types can be added without modifying the core App logic
5. **Consistent Architecture**: Aligns with existing patterns like `FileWorker` protocol for dependency injection

## Scope
This change focuses purely on code organization and does not modify any business logic or external APIs. All existing functionality will be preserved with identical behavior.

## Dependencies
- No external dependencies
- No breaking changes to existing interfaces
- Compatible with current testing infrastructure