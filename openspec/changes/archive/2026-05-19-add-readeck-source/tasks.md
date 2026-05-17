## 1. Configuration

- [x] 1.1 Add optional `readeckEndpoint` and `readeckApiToken` (as `SecretString`) fields to `Config` struct in `ConfigReader.swift`
- [x] 1.2 Update `readConfig()` to parse optional Readeck fields from YAML
- [x] 1.3 Add runtime validation: when `--readeck` flag is active, ensure both Readeck config fields are present; exit with descriptive error if missing

## 2. Readeck API Models

- [x] 2.1 Create `Sources/stylus/Readeck/BookmarkSyncEntry.swift` — DTO for `/bookmarks/sync` response: `{id: String, time: String, type: String ("update"|"delete")}`
- [x] 2.2 Create `Sources/stylus/Readeck/BookmarkDetail.swift` — DTO for `GET /bookmarks/{id}` response with fields: `id`, `title`, `url`, `created`, `labels`, `isArchived`

## 3. Readeck API Client

- [x] 3.1 Create `Sources/stylus/Readeck/ReadeckClient.swift` — struct with `URLSession`-based HTTP client, Bearer token auth via `Authorization` header
- [x] 3.2 Implement `fetchSyncedBookmarks(since: String?) async throws -> [BookmarkSyncEntry]` — calls `GET /bookmarks/sync?since=<timestamp>` (omit `since` when nil for initial sync)
- [x] 3.3 Implement `fetchBookmark(id: String) async throws -> BookmarkDetail` — calls `GET /bookmarks/{id}` for full bookmark details
- [x] 3.4 Handle HTTP 401 with descriptive error; handle network errors gracefully

## 4. Last Fetch Timestamp Manager

- [x] 4.1 Create `Sources/stylus/Readeck/ReadeckFetchTimestamp.swift` — follows `OffsetManager` pattern: read/write ISO 8601 timestamp to `readeck_last_fetch.txt` with atomic writes
- [x] 4.2 Implement `readLastFetch() -> String?` and `writeLastFetch(_ timestamp: String) throws`

## 5. Bookmark-to-Journal Transformation

- [x] 5.1 Create `Sources/stylus/Readeck/BookmarkJournalTransformer.swift` — converts `BookmarkDetail` to journal entry format: `- **HH:mm** [Title](url) #from-readeck #label1 #label2 #stylus-inbox\n`
- [x] 5.2 Handle edge cases: empty title → use URL as link text; empty labels → only `#from-readeck #stylus-inbox`; parse `created` date for time string and journal file date; always include `#from-readeck` source tag; convert each Readeck label to a separate `#tag`

## 6. Readeck Sync Runner

- [x] 6.1 Create `Sources/stylus/Readeck/ReadeckSyncRunner.swift` — orchestrates the full sync flow: read last fetch → call sync API → fetch details for updates → transform to entries → write to journal files → update timestamp
- [x] 6.2 Ensure journal files are written to `knowledgeBaseLocation/journals/yyyy_MM_dd.md` (reusing existing `JournalWriter`)
- [x] 6.3 Only update timestamp after all bookmarks are successfully processed; do NOT update on partial failure

## 7. Entry Point Integration

- [x] 7.1 Update `Stylus.swift` main function to parse `--readeck` flag from `CommandLine.arguments`
- [x] 7.2 Branch execution: `--readeck` → run `ReadeckSyncRunner`; no flag → run existing Telegram `App`

## 8. Tests

- [x] 8.1 Test `ReadeckClient` with mocked URLSession — verify Bearer token header, sync endpoint URL construction, bookmark detail parsing
- [x] 8.2 Test `ReadeckFetchTimestamp` — read/write/atomic operations, first-run nil case
- [x] 8.3 Test `BookmarkJournalTransformer` — various combinations of title/labels/empty fields produce correct markdown; verify `#from-readeck` is always present; verify labels become separate `#tag` entries
- [x] 8.4 Test config validation — missing Readeck fields when `--readeck` is active produces error
- [x] 8.5 Test `ReadeckSyncRunner` integration — mock API responses, verify journal entries written, verify timestamp updated only on success
