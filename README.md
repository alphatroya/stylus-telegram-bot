# Stylus Telegram Bot

A Telegram bot that captures messages and automatically saves them to daily journal files in Markdown format. Also syncs bookmarks from a [Readeck](https://readeck.org/) instance into the same journal format. Perfect for quickly collecting thoughts, links, and ideas throughout the day and integrating them into your personal knowledge base. The journal format is compatible with [Logseq](https://logseq.com/).

## Features

- **Automatic Daily Journals**: Creates and appends entries to date-based journal files (e.g., `2025_11_21.md`)
- **Logseq Compatible**: Journal format is fully compatible with Logseq for seamless integration
- **Smart Link Processing**: Automatically fetches page titles for URLs and converts them to Markdown links
- **Readeck Bookmark Sync**: Syncs bookmarks from your Readeck instance into daily journals as tagged entries
- **Incremental Sync**: Only fetches new/updated bookmarks since the last sync using a persisted timestamp
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
readeckEndpoint: "https://your-readeck-instance.example.com"  # optional
readeckApiToken: "YOUR_READECK_API_TOKEN"                  # optional
```

The bot searches for the config file in the following locations (in order):
1. Current directory: `./config.yaml`
2. Home config directory: `~/.config/stylus/config.yaml`
3. Application support directory: `~/Library/Application Support/stylus/config.yaml`

### Configuration Fields

- `telegramBotApiKey`: Your Telegram Bot API token (get it from [@BotFather](https://t.me/botfather))
- `telegramUserId`: Your Telegram user ID (only messages from this user will be processed)
- `knowledgeBaseLocation`: Path where journal files will be stored (a `journals` subdirectory will be created). Compatible with Logseq graph directories.
- `readeckEndpoint`: (optional) URL of your Readeck instance. Required when using `--readeck` mode.
- `readeckApiToken`: (optional) Readeck API token for authentication. Required when using `--readeck` mode.

### Getting Your Telegram User ID

You can get your Telegram user ID by:
1. Start a chat with [@userinfobot](https://t.me/userinfobot)
2. The bot will reply with your user ID

### Creating a Telegram Bot

1. Talk to [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot` and follow the instructions
3. Copy the API token provided by BotFather

## Usage

### Telegram Bot Mode (default)

Once configured and running, simply send messages to your bot:

**Example Input:**
```
Check out this article https://swift.org/blog/announcing-swift-6/
```

**Saved to Journal:**
```markdown
- TODO **14:30** Check out this article [Announcing Swift 6](https://swift.org/blog/announcing-swift-6/) #stylus-inbox
```

### Readeck Sync Mode

Sync bookmarks from your Readeck instance into daily journal files:

```bash
swift run stylus --readeck
```

This will:
1. Read the last sync timestamp (first run performs a full sync)
2. Fetch all changed bookmarks from the Readeck `/bookmarks/sync` API
3. Retrieve full details for each updated bookmark
4. Transform bookmarks into journal entries tagged with `#from-readeck` and Readeck labels
5. Write entries to the appropriate daily journal files
6. Persist the sync timestamp for incremental updates

**Example Journal Entry:**
```markdown
- **09:15** [Announcing Swift 6](https://swift.org/blog/announcing-swift-6/) #from-readeck #swift #programming #stylus-inbox
```

The sync timestamp is stored in a `readeck_last_fetch.txt` file alongside your config file, enabling incremental syncs on subsequent runs.

> **Note:** Both `readeckEndpoint` and `readeckApiToken` must be set in your config file when using `--readeck` mode. Self-signed certificates are supported for localhost connections.

## Development

### Project Structure

```
Sources/stylus/
├── Bot/
│   ├── Bot.swift                    # Bot protocol definition
│   └── TelegramBot.swift            # Telegram Bot API implementation
├── Core/
│   └── App.swift                    # Main bot application logic
├── Message/
│   ├── DateFormatter.swift          # Date formatting utilities
│   ├── LinkProcessor.swift          # URL extraction and metadata fetching
│   ├── MessageHandler.swift         # Message handling logic
│   └── TagManager.swift             # Tag management functionality
├── Readeck/
│   ├── BookmarkDetail.swift         # Bookmark detail DTO
│   ├── BookmarkJournalTransformer.swift  # Bookmark → journal entry conversion
│   ├── BookmarkSyncEntry.swift      # Sync entry DTO
│   ├── ReadeckClient.swift          # Readeck REST API client
│   ├── ReadeckFetchTimestamp.swift   # Sync timestamp persistence
│   └── ReadeckSyncRunner.swift      # Full sync orchestration
├── Storage/
│   ├── FileWorker.swift             # File system operations protocol
│   └── JournalWriter.swift          # Journal file writing operations
├── Config/
│   ├── ConfigReader.swift           # Configuration parsing
│   ├── ConfigPath.swift             # Configuration file path resolution
│   └── OffsetManager.swift          # Telegram update offset persistence
└── Stylus.swift                     # Application entry point (CLI)

Tests/stylusTests/
├── Bot/
├── Config/
│   ├── ConfigReaderTests.swift
│   └── OffsetManagerTests.swift
├── Core/
│   └── AppTests.swift
├── Message/
│   ├── DateFormatterTests.swift
│   ├── LinkProcessorTests.swift
│   ├── MessageHandlerTests.swift
│   └── TagManagerTests.swift
├── Readeck/
│   ├── BookmarkJournalTransformerTests.swift
│   ├── ConfigValidationTests.swift
│   ├── ReadeckClientTests.swift
│   ├── ReadeckFetchTimestampTests.swift
│   └── ReadeckSyncRunnerTests.swift
├── Storage/
│   └── JournalWriterTests.swift
├── StylusCommandTests.swift
└── Mocks.swift
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

Run a specific test:
```bash
swift test --filter <test_name>
```

Format code with swiftformat:
```bash
swiftformat .
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
