# GitHub Copilot Instructions for Stylus Telegram Bot

## Project Overview

**Stylus Telegram Bot** is a Telegram bot that captures messages and automatically saves them to daily journal files in Markdown format. The journal format is compatible with [Logseq](https://logseq.com/).

**Key Features:**
- Automatic Daily Journals: Creates and appends entries to date-based journal files
- Logseq Compatible: Journal format is fully compatible with Logseq
- Smart Link Processing: Fetches page titles for URLs and converts them to Markdown links
- Timestamped Entries: Each entry includes the time it was sent
- Task Format: All entries are saved as TODO items
- Tagging System: Automatically adds `#stylus-inbox` tag
- User Authentication: Only processes messages from authorized users

## Tech Stack

- **Language**: Swift 6.2
- **Platform**: macOS 15.0+
- **Testing**: Swift Testing framework
- **Dependencies**: 
  - telegram-bot-swift (Telegram Bot API SDK)
  - swift-configuration (Configuration file parsing)
  - Yams (YAML parser)

## Project Structure

```
Sources/stylus/
├── Core/
│   └── Bot.swift              # Main bot logic and message handling
├── Message/
│   ├── DateFormatter.swift    # Date formatting utilities
│   ├── LinkProcessor.swift    # URL extraction and metadata fetching
│   └── TagManager.swift       # Tag management functionality
├── Storage/
│   ├── FileWorker.swift       # File system operations protocol
│   └── JournalWriter.swift    # Journal file writing operations
├── Config/
│   ├── ConfigReader.swift     # Configuration parsing
│   └── ConfigPath.swift       # Configuration file path resolution
└── Stylus.swift               # Application entry point

Tests/stylusTests/
├── Config/
│   └── ConfigReaderTests.swift
├── Message/
│   ├── DateFormatterTests.swift
│   ├── LinkProcessorTests.swift
│   └── TagManagerTests.swift
└── Storage/
    └── JournalWriterTests.swift
```

## Development Commands

- **Build**: `swift build`
- **Test**: `swift test`
- **Test single**: `swift test --filter <test_name>`
- **Run**: `swift run stylus`
- **Format**: `swiftformat .` (or use mise: `mise exec -- swiftformat .`)

## Code Style Guidelines

- Use Swift 6.2 with modern concurrency (target: macOS 15+)
- Format with swiftformat (mise-managed, max width 140 chars)
- Use Swift Testing framework (#expect, @Test, @Suite with descriptive names)
- Prefer guard statements over nested ifs for early returns
- Use `// MARK: - ClassName` comments for type organization
- Keep imports minimal and organized (Foundation first, then third-party)
- Use async/await for asynchronous operations, avoid completion handlers
- Prefer structs over classes, mark classes as final when inheritance not needed
- Use dependency injection for file system operations (FileWorker protocol)
- Avoid force unwrapping, use guard/if-let or nil-coalescing
- Use descriptive variable/function names (messageDateFormatted vs dateStr)
- Handle errors explicitly with do-catch, don't use try! in production code
- Use @testable import for accessing internal APIs in tests
- Prefer parameterized tests with @Test(arguments:) for multiple test cases

## Testing Guidelines

- Always write tests for new features
- Run `swift test` before committing
- Use descriptive test names that explain what is being tested
- Use @testable import to access internal APIs
- Mock file system operations using FileWorker protocol
- Test both success and error cases
- Use @Test(arguments:) for parameterized tests when testing multiple scenarios

## Important Rules

- ✅ Write tests for all new features
- ✅ Run `swift test` before committing
- ✅ Format code with `swiftformat .` before committing
- ✅ Use protocol-based design for testability
- ✅ Follow Swift 6.2 concurrency patterns (async/await)
- ❌ Do NOT use force unwrapping (!) in production code
- ❌ Do NOT use completion handlers, use async/await instead
- ❌ Do NOT use try! in production code, handle errors properly