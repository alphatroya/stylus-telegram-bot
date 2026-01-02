# Project Context

## Purpose
Stylus is a Telegram bot designed for seamless personal knowledge management and journaling. The bot automatically captures messages sent to it and saves them to daily journal files in Markdown format, specifically compatible with [Logseq](https://logseq.com/). 

**Key Goals:**
- Enable quick capture of thoughts, links, and ideas throughout the day via Telegram
- Create structured daily journal entries with automatic timestamping
- Process URLs intelligently by fetching page titles and converting to Markdown links
- Support multimedia content (images, documents) with organized asset management
- Provide seamless integration with Logseq for personal knowledge base workflows
- Maintain security through user authentication (only authorized users can add entries)

## Tech Stack
- **Swift 6.2** - Modern Swift with strict concurrency and async/await
- **macOS 15+** - Target platform with LinkPresentation framework support
- **Swift Package Manager** - Dependency management and build system
- **Swift Configuration + Yams** - YAML configuration file parsing
- **TelegramBotSDK** - Telegram Bot API integration
- **Swift Testing** - Modern testing framework (replacing XCTest)
- **SwiftFormat** - Code formatting and style enforcement
- **Mise** - Tool version management
- **Jujutsu** - Version control system

## Project Conventions

### Code Style
- Swift 6.2 with modern concurrency (target: macOS 15+)
- Maximum line width: 140 characters
- SwiftFormat configuration with specific rules enabled
- Use `// MARK: - ClassName` comments for type organization
- Prefer structs over classes, mark classes as final when inheritance not needed
- Use descriptive variable/function names (messageDateFormatted vs dateStr)
- Keep imports minimal and organized (Foundation first, then third-party)
- Avoid force unwrapping, use guard/if-let or nil-coalescing
- Handle errors explicitly with do-catch, don't use try! in production code
- Use dependency injection for file system operations (FileWorker protocol)

### Architecture Patterns
- **Protocol-based design** for testability and dependency injection
- **Modular architecture** with clear separation of concerns:
  - `Core/` - Main application logic and bot coordination
  - `Message/` - Message processing, date formatting, link processing, tagging
  - `Storage/` - File operations and journal writing
  - `Config/` - Configuration management and path resolution
  - `Bot/` - Telegram bot abstraction and communication
- **Async/await concurrency** throughout, avoiding completion handlers
- **Error handling** with custom error types and descriptive messages
- **Dependency injection** using protocols for testable file operations
- **Single responsibility principle** with focused, small modules

### Testing Strategy
- **Swift Testing framework** with modern #expect syntax instead of XCTest
- **@Test and @Suite** with descriptive names for better test organization
- **@testable import** for accessing internal APIs in tests
- **Parameterized tests** with @Test(arguments:) for multiple test cases
- **Protocol-based mocking** for file system operations and external dependencies
- **Comprehensive unit tests** for all message processing logic
- **Integration tests** for configuration loading and file operations
- Run tests with: `swift test` or `swift test --filter <test_name>`

### Git Workflow
- **Jujutsu (jj)** as version control system instead of Git
- Descriptive commit messages focusing on "why" rather than "what"
- Feature branches for new functionality
- Clean, atomic commits with single responsibility
- Code review process for significant changes
- Automated formatting with SwiftFormat before commits

## Domain Context

### Telegram Bot Development
- Understanding of Telegram Bot API limitations and capabilities
- Message types: text, images, documents with optional captions
- File handling through Telegram's file API with size limitations
- User authentication via Telegram user IDs for security
- Bot token management and configuration security

### Personal Knowledge Management
- **Logseq compatibility** - specific Markdown format requirements
- **Daily journaling workflow** - date-based file organization (YYYY_MM_DD.md)
- **TODO format** - all entries saved as `- TODO **HH:mm** content #stylus-inbox`
- **Asset organization** - images/documents stored in `assets/` directory
- **Tagging system** - automatic `#stylus-inbox` tagging for filtering
- **Link processing** - intelligent URL title fetching and Markdown conversion

### File System Operations
- Journal files organized in `journals/` subdirectory
- Asset files in `assets/` subdirectory with collision handling
- Unique filename generation with UUID suffixes for conflicts
- Directory creation and path safety validation
- Cross-platform file path handling (macOS focused)

## Important Constraints

### Technical Constraints
- **macOS 15.0+ requirement** - LinkPresentation framework dependency
- **Swift 6.2+ requirement** - Modern concurrency and language features
- **Single-user design** - One authorized Telegram user per bot instance
- **File system access** - Requires write permissions to knowledge base location
- **Network dependency** - Requires internet for Telegram API and URL fetching

### Security Constraints
- **User ID validation** - Only configured Telegram user can add entries
- **Path traversal prevention** - Sanitization of user-provided filenames
- **Token security** - Bot token stored in configuration files, not in code
- **File access control** - Limited to configured knowledge base directory

### Platform Constraints
- **macOS-specific** - Uses Apple's LinkPresentation for URL metadata
- **Command-line tool** - Designed for server/background execution
- **Configuration-dependent** - Requires proper YAML configuration file

## External Dependencies

### Telegram Bot API
- **telegram-bot-swift** library for API communication
- Handles message polling, file downloads, and response sending
- Requires valid bot token from @BotFather
- Subject to Telegram's rate limits and file size restrictions

### Apple LinkPresentation Framework
- Used for fetching URL metadata and page titles
- macOS 15.0+ system framework dependency
- Provides rich link previews for better Markdown link generation

### Configuration Management
- **swift-configuration** for structured config parsing
- **Yams** for YAML file parsing and validation
- Supports multiple configuration file locations with fallback priority

### Development Tools
- **SwiftFormat** for code style enforcement
- **Mise** for tool version management
- **Swift Package Manager** for dependency resolution and building
