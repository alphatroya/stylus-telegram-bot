# GitHub Copilot Instructions for Stylus Telegram Bot

## Project Overview

**Stylus Telegram Bot** is a Telegram bot that captures messages and automatically saves them to daily journal files in Markdown format. It's designed for quickly collecting thoughts, links, and ideas throughout the day and integrating them into your personal knowledge base.

**Key Features:**
- Automatic daily journals with date-based file naming
- Logseq-compatible journal format
- Smart link processing with automatic page title fetching
- Timestamped entries saved as TODO items
- Automatic tagging with `#stylus-inbox`
- User authentication for authorized Telegram users only

## Tech Stack

- **Language**: Swift 6.2
- **Platform**: macOS 15.0+
- **Package Manager**: Swift Package Manager
- **Testing**: Swift Testing framework
- **Code Formatting**: SwiftFormat
- **Dependencies**:
  - TelegramBotSDK - Telegram Bot API integration
  - swift-configuration - Configuration file parsing
  - Yams - YAML parsing

## Project Structure

```
stylus-telegram-bot/
├── Sources/stylus/
│   ├── Core/
│   │   └── Bot.swift              # Main bot logic and message handling
│   ├── Message/
│   │   ├── DateFormatter.swift    # Date formatting utilities
│   │   ├── LinkProcessor.swift    # URL extraction and metadata fetching
│   │   └── TagManager.swift       # Tag management functionality
│   ├── Storage/
│   │   ├── FileWorker.swift       # File system operations protocol
│   │   └── JournalWriter.swift    # Journal file writing operations
│   ├── Config/
│   │   ├── ConfigReader.swift     # Configuration parsing
│   │   └── ConfigPath.swift       # Configuration file path resolution
│   └── Stylus.swift               # Application entry point
├── Tests/stylusTests/
│   ├── Config/
│   │   └── ConfigReaderTests.swift
│   ├── Message/
│   │   ├── DateFormatterTests.swift
│   │   ├── LinkProcessorTests.swift
│   │   └── TagManagerTests.swift
│   └── Storage/
│       └── JournalWriterTests.swift
├── Package.swift                  # Swift package manifest
├── AGENTS.md                      # AI agent guide with bd integration
└── README.md                      # User documentation
```

## Coding Guidelines

### Building and Testing
- Build: `swift build`
- Test: `swift test`
- Test single: `swift test --filter <test_name>`
- Run: `swift run stylus`
- Format: `swiftformat .`

### Code Style
- Use Swift 6.2 with modern concurrency (async/await)
- Format with SwiftFormat (max width 140 chars)
- Use Swift Testing framework (`#expect`, `@Test`, `@Suite`)
- Prefer guard statements over nested ifs for early returns
- Use `// MARK: - ClassName` comments for type organization
- Keep imports minimal and organized (Foundation first, then third-party)
- Prefer structs over classes, mark classes as final when inheritance not needed
- Use dependency injection for file system operations (FileWorker protocol)
- Avoid force unwrapping, use guard/if-let or nil-coalescing
- Use descriptive variable/function names
- Handle errors explicitly with do-catch
- Use `@testable import` for accessing internal APIs in tests
- Prefer parameterized tests with `@Test(arguments:)` for multiple test cases

## Issue Tracking with bd

**CRITICAL**: This project uses **bd (beads)** for ALL task tracking. Do NOT create markdown TODO lists.

### Essential Commands

```bash
# Find work
bd ready --json                    # Unblocked issues
bd stale --days 30 --json          # Forgotten issues

# Create and manage
bd create "Title" -t bug|feature|task -p 0-4 --json
bd update <id> --status in_progress --json
bd close <id> --reason "Done" --json

# Search
bd list --status open --priority 1 --json
bd show <id> --json
```

### Workflow

1. **Check ready work**: `bd ready --json`
2. **Claim task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** `bd create "Found bug" -p 1 --deps discovered-from:<parent-id> --json`
5. **Complete**: `bd close <id> --reason "Done" --json`
6. **Commit together**: Always commit `.beads/issues.jsonl` with code changes

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

## Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Run `swift test` before committing
- ✅ Format code with `swiftformat .`
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT commit `.beads/beads.db` (JSONL only)

---

**For detailed workflows and advanced features, see [AGENTS.md](../AGENTS.md)**