# Message Handling Specification

## ADDED Requirements

### Requirement: MessageHandler Protocol Definition
The system SHALL define a `MessageHandler` protocol that abstracts all message processing operations previously embedded in the App struct.

#### Scenario: Protocol method definitions
**Given** the need to handle different Telegram message types  
**When** the MessageHandler protocol is defined  
**Then** it SHALL include methods for:
- `handleJustTextMessage(text: String, timeString: String, filePath: String, originalSender: Message.From?) async throws`
- `handleImageMessage(fileId: String, caption: String?, timeString: String, filePath: String, originalSender: Message.From?) async throws`  
- `handleDocumentMessage(fileId: String, fileName: String?, caption: String?, timeString: String, filePath: String, originalSender: Message.From?) async throws`
- `handleMessageType(_ messageType: Message.MessageType, timeString: String, filePath: String, originalSender: Message.From?) async`
- `saveFileWithUniqueFilename(data: Data, baseFileName: String, assetsURL: URL) async throws -> String`

### Requirement: DefaultMessageHandler Implementation  
The system SHALL provide a concrete `DefaultMessageHandler` struct that implements the MessageHandler protocol with all existing message processing logic.

#### Scenario: Preserved functionality
**Given** the existing message processing logic in App.swift  
**When** DefaultMessageHandler is implemented  
**Then** all message processing behavior SHALL remain identical including:
- Text message processing with link processing and tagging
- Image message handling with asset storage and caption processing  
- Document message handling with filename sanitization and storage
- File collision handling with unique filename generation
- Media entry formatting with user tags and timestamps

#### Scenario: Dependency injection support
**Given** the MessageHandler needs access to other services  
**When** DefaultMessageHandler is initialized  
**Then** it SHALL accept and store references to:
- `Config` for knowledge base location and user validation
- `JournalWriter` for file operations
- `LinkProcessor` for URL processing  
- `Bot` for file downloads
- Any other dependencies currently used by handler functions

### Requirement: App Struct Simplification
The App struct SHALL be refactored to focus solely on application orchestration by delegating all message handling to the MessageHandler.

#### Scenario: Dependency injection pattern  
**Given** the App struct needs message handling capabilities  
**When** App is initialized  
**Then** it SHALL accept a MessageHandler instance through dependency injection

#### Scenario: Handler delegation
**Given** a message needs to be processed  
**When** App.processMessage is called  
**Then** it SHALL delegate to the injected MessageHandler instance rather than handling messages directly

#### Scenario: Removed responsibilities
**Given** the refactored App struct  
**When** reviewing its contents  
**Then** it SHALL NOT contain:
- Message type-specific handling logic
- File saving operations for attachments
- Media entry formatting functions  
- Message content processing logic

## MODIFIED Requirements

### Requirement: App Structure and Responsibilities
The App struct's responsibilities SHALL be limited to application lifecycle and coordination only.

#### Scenario: Focused responsibilities
**Given** the refactored App struct  
**When** examining its methods and properties  
**Then** it SHALL only be responsible for:
- Bot lifecycle management (`run()` method)
- Message fetching and orchestration
- Offset management for message polling
- High-level error handling and logging
- Coordination between services

## REMOVED Requirements  

### Requirement: Direct Message Processing in App
The App struct SHALL NOT directly implement message processing logic.

#### Scenario: No embedded handlers
**Given** the refactored App struct  
**When** reviewing its implementation  
**Then** it SHALL NOT contain methods for:
- `handleJustTextMessage`
- `handleImageMessage` 
- `handleDocumentMessage`
- `formatMediaEntry`
- `saveFileWithUniqueFilename`