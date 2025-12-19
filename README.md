# Stylus Telegram Bot

A Telegram bot that captures messages and automatically saves them to daily journal files in Markdown format. Perfect for quickly collecting thoughts, links, and ideas throughout the day and integrating them into your personal knowledge base. The journal format is compatible with [Logseq](https://logseq.com/).

## Features

- **Automatic Daily Journals**: Creates and appends entries to date-based journal files (e.g., `2025_11_21.md`)
- **Logseq Compatible**: Journal format is fully compatible with Logseq for seamless integration
- **Smart Link Processing**: Automatically fetches page titles for URLs and converts them to Markdown links
- **Timestamped Entries**: Each entry includes the time it was sent
- **Task Format**: All entries are saved as TODO items for easy task management
- **Tagging System**: Automatically adds `#stylus-inbox` tag to entries for organization
- **User Authentication**: Only processes messages from authorized Telegram users

## How It Works

When you send a message to the bot:

1. The bot extracts any URLs from your message
2. It fetches the page titles for those URLs
3. It converts the URLs to Markdown links: `[Page Title](https://example.com)`
4. It adds a `#stylus-inbox` tag to the first line
5. It appends the entry to today's journal file in this format:
   ```markdown
   - TODO **HH:mm** Your message with [links](https://example.com) #stylus-inbox
   ```

## Requirements

- macOS 15.0 or later
- Swift 6.2 or later
- Uses Apple's LinkPresentation framework (for URL metadata fetching, available on macOS 15.0+)

## Installation

### Using Swift Package Manager

1. Clone the repository:
   ```bash
   git clone https://github.com/alphatroya/stylus-telegram-bot.git
   cd stylus-telegram-bot
   ```

2. Build the project:
   ```bash
   swift build
   ```

3. Run the bot:
   ```bash
   swift run
   ```

## Configuration

The bot requires a YAML configuration file named `config.yaml` with the following settings:

```yaml
telegramBotApiKey: "YOUR_BOT_TOKEN"
telegramUserId: 123456789
knowledgeBaseLocation: "/path/to/your/knowledge/base"
```

The bot searches for the config file in the following locations (in order):
1. Current directory: `./config.yaml`
2. Home config directory: `~/.config/stylus/config.yaml`
3. Application support directory: `~/Library/Application Support/stylus/config.yaml`

### Configuration Fields

- `telegramBotApiKey`: Your Telegram Bot API token (get it from [@BotFather](https://t.me/botfather))
- `telegramUserId`: Your Telegram user ID (only messages from this user will be processed)
- `knowledgeBaseLocation`: Path where journal files will be stored (a `journals` subdirectory will be created). Compatible with Logseq graph directories.

### Getting Your Telegram User ID

You can get your Telegram user ID by:
1. Start a chat with [@userinfobot](https://t.me/userinfobot)
2. The bot will reply with your user ID

### Creating a Telegram Bot

1. Talk to [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot` and follow the instructions
3. Copy the API token provided by BotFather

## Usage

Once configured and running, simply send messages to your bot:

**Example Input:**
```
Check out this article https://swift.org/blog/announcing-swift-6/
```

**Saved to Journal:**
```markdown
- TODO **14:30** Check out this article [Announcing Swift 6](https://swift.org/blog/announcing-swift-6/) #stylus-inbox
```

## Development

### Project Structure

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

### Building and Testing

Build the project:
```bash
swift build
```

Run tests:
```bash
swift test
```

Run tests with code coverage:
```bash
swift test --enable-code-coverage
```

Run a specific test:
```bash
swift test --filter <test_name>
```

Format code with swiftformat:
```bash
swiftformat .
```

Lint code with swiftlint:
```bash
swiftlint lint
```

### Code Coverage

The project includes code coverage tracking in CI/CD:
- Coverage runs as a separate check in GitHub Actions
- Coverage reports are generated in LCOV format and uploaded to [Codecov](https://codecov.io)
- Coverage analysis runs in parallel with the main test suite
- The coverage check is independent and won't block the test job

To view coverage locally:
```bash
# Run tests with coverage
swift test --enable-code-coverage

# Find the test binary (usually <PackageName>PackageTests.xctest)
TEST_BINARY=$(find .build/debug -name "*.xctest" -type d | head -n 1)

# Generate coverage report
xcrun llvm-cov report \
  "$TEST_BINARY/Contents/MacOS/$(basename $TEST_BINARY .xctest)" \
  -instr-profile .build/debug/codecov/default.profdata
```

### Code Style

This project follows Swift best practices:
- Swift 6.2 with modern concurrency (async/await)
- Swift Testing framework for tests
- Protocol-based design for testability
- MARK comments for code organization
- Descriptive naming conventions

## Dependencies

- [telegram-bot-swift](https://github.com/rapierorg/telegram-bot-swift) - Telegram Bot API SDK
- [swift-configuration](https://github.com/apple/swift-configuration) - Configuration file parsing
- [Yams](https://github.com/jpsim/Yams) - YAML parser

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Alexey Korolev ([@alphatroya](https://github.com/alphatroya))

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
