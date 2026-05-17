## Why

Stylus currently processes Telegram messages as the sole data source for journal entries. Adding Readeck as a second data source enables users to sync their saved bookmarks/articles into the knowledge base automatically. This creates a unified inbox where both conversational notes (via Telegram) and saved reading material (via Readeck) flow into daily journal files. The sync should be incremental using a stored last-fetch timestamp to avoid re-processing already imported bookmarks.

## What Changes

- Add a new CLI flag (e.g., `--readeck`) to switch the bot into Readeck sync mode
- Implement a Readeck API client that authenticates via Bearer token against a Readeck server instance
- Fetch bookmarked articles incrementally using `GET /bookmarks/sync?since=<last_fetch_timestamp>` to retrieve only new/updated bookmarks since last sync
- Store the last successful fetch timestamp in a persistent file (alongside the existing `telegram_offset.txt` pattern) so subsequent runs only fetch deltas
- Transform Readeck bookmarks into journal entries (markdown links with titles, `#from-readeck` source tag, and Readeck labels as separate `#tag` entries) and append them to daily journal files
- Add Readeck configuration fields to the YAML config: `readeckEndpoint`, `readeckApiToken`
- The existing Telegram message-processing mode remains the default when no flag is provided

## Capabilities

### New Capabilities
- `readeck-sync`: Fetches bookmarks from a Readeck instance incrementally and writes them as journal entries, storing last-fetch timestamp for delta syncs

### Modified Capabilities
<!-- No existing capabilities are modified -->

## Impact

- **Config**: New YAML fields (`readeckEndpoint`, `readeckApiToken`) — optional, only required when using Readeck mode
- **New files**: Readeck API client, bookmark DTO models, last-fetch timestamp manager
- **Existing code**: `Stylus.swift` entry point needs flag parsing to branch between Telegram and Readeck modes; `Config` struct gains optional Readeck fields
- **Dependencies**: No new external dependencies (uses Foundation URLSession for HTTP, matching the project's current approach)
- **API reference**: Based on Readeck OpenAPI spec — Bearer token auth, `/bookmarks/sync` endpoint with `since` parameter, `/bookmarks/{id}` for full bookmark details
