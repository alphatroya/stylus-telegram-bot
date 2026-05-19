## Context

Stylus is a CLI tool that runs in one-shot mode: it processes pending Telegram messages and writes journal entries to daily markdown files in a knowledge base. The bot currently has a single data source (Telegram via long-polling). The config is read from a YAML file, and state (message offset) is persisted in a simple text file alongside the config.

Readeck is a self-hosted read-later service with a REST API. It supports Bearer token authentication and provides a `/bookmarks/sync` endpoint that returns only bookmarks changed since a given datetime — ideal for incremental syncs.

The existing codebase uses plain Foundation (`URLSession`) for HTTP and has no external HTTP dependencies. This should be preserved.

## Goals / Non-Goals

**Goals:**
- Enable Stylus to run in a second mode: Readeck sync
- Use `--readeck` CLI flag to activate Readeck mode (default remains Telegram mode)
- Incrementally fetch only new/updated bookmarks using `GET /bookmarks/sync?since=<timestamp>`
- Persist last-fetch timestamp between runs for delta sync
- Transform bookmarks into journal entries with titles, cleaned URLs, and labels as tags
- Keep the implementation consistent with existing patterns (simple structs, no external deps, FileWorker for I/O)

**Non-Goals:**
- Full Readeck API client (only sync + bookmark detail needed)
- OAuth authentication (use simple API token only)
- Two-way sync (Stylus will not write back to Readeck)
- Fetching article body content (only bookmark metadata: title, URL, labels, dates)
- Running both Telegram and Readeck modes simultaneously in one invocation

## Decisions

### 1. CLI flag via simple argument parsing

**Decision**: Use `CommandLine.arguments` parsing in `Stylus.swift` — check for `--readeck` flag.

**Rationale**: The project has no argument-parser dependency and the flag set is minimal (one flag). Adding Swift Argument Parser would be over-engineering for a single toggle. If more flags are needed later, migration is straightforward.

**Alternative**: Swift Argument Parser — rejected due to single-flag scope.

### 2. Config extends existing YAML with optional Readeck fields

**Decision**: Add optional `readeckEndpoint` and `readeckApiToken` fields to the existing YAML config. They are only required when `--readeck` mode is active.

**Rationale**: Follows the existing pattern of a single config file. The fields are optional at the Config level — validation happens at runtime only when Readeck mode is invoked.

### 3. Readeck API client as a standalone struct

**Decision**: Create `ReadeckClient` struct using `URLSession` with Bearer token auth, mirroring the iOS client's approach but simplified for CLI use.

**Rationale**: Consistent with the project's zero-dependency HTTP approach. The client only needs two endpoints: `/bookmarks/sync` (list changed IDs) and optionally `/bookmarks/{id}` (if full bookmark detail is needed from sync results). The Readeck iOS app's `API.swift` confirms Bearer token in the Authorization header.

### 4. Timestamp persistence alongside telegram_offset.txt

**Decision**: Create `readeck_last_fetch.txt` in the same config directory, storing an ISO 8601 datetime string. Follow `OffsetManager`'s atomic write pattern.

**Rationale**: Mirrors the proven `OffsetManager` pattern. ISO 8601 format matches the Readeck API's `since` parameter. Atomic writes prevent corruption on crash.

**Alternative**: Store in YAML config file — rejected because config is read-only and the timestamp changes every run.

### 5. Bookmark sync uses `/bookmarks/sync` for incremental fetching

**Decision**: Use `GET /bookmarks/sync?since=<last_fetch>` to get a list of `{id, time, type: "update"|"delete"}` entries. For "update" entries, fetch full bookmark details via `GET /bookmarks/{id}`. Skip "delete" entries.

**Rationale**: The `/bookmarks/sync` endpoint is purpose-built for incremental sync (confirmed in Readeck OpenAPI spec). It returns minimal data (ID + change type), requiring a follow-up fetch for details. This is more efficient than filtering the full bookmark list by date.

**Alternative**: Use `GET /bookmarks?range_start=<date>` — rejected because `/bookmarks/sync` is the canonical sync endpoint and handles deletions.

### 6. Journal entry format for bookmarks

**Decision**: Each bookmark becomes a single markdown line:
```
- **HH:mm** [Title](url) #from-readeck #label1 #label2 #stylus-inbox
```
Bookmarks are grouped under the date they were created in Readeck (using `created` field). Every bookmark entry includes `#from-readeck` to identify its source. Readeck labels are converted to individual `#tag` entries. The `#stylus-inbox` tag is appended last to match existing journal convention.

**Rationale**: Consistent with the existing `- TODO **HH:mm** text` format used for Telegram messages. Using the bookmark's creation date (not sync date) groups entries correctly in daily files. The `#from-readeck` tag distinguishes Readeck-sourced entries from Telegram-sourced entries in the unified journal.

## Risks / Trade-offs

- **[Readeck server unreachable]** → The bot should fail gracefully with a clear error message and NOT update the last-fetch timestamp, so the next run retries the same window
- **[Large number of bookmarks on first sync]** → No pagination on `/bookmarks/sync` — if the initial sync returns hundreds of bookmarks, all will be processed in one run. Acceptable for a CLI tool; can add batching later if needed
- **[Clock skew between client and server]** → The `since` parameter uses server-side timestamps, so the stored timestamp should come from the last bookmark's `time` field in the sync response, not client clock
- **[Breaking change to config]** → New fields are optional — no migration needed, existing configs continue to work
