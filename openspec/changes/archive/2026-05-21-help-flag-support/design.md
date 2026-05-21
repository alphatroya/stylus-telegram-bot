## Context

Stylus is a Swift CLI executable that runs in two modes: default Telegram bot mode and `--readeck` sync mode. The current entry point (`Stylus.swift`) uses raw `CommandLine.arguments.contains("--readeck")` to switch modes with no help system, argument validation, or usage documentation. The project is a single executable target with no external argument parsing library.

## Goals / Non-Goals

**Goals:**
- Provide `--help`/`-h` flag that prints usage information and exits cleanly
- Introduce structured argument parsing to replace ad-hoc `CommandLine.arguments.contains()` checks
- Display available modes and flags in a clear help output
- Handle unrecognized flags gracefully

**Non-Goals:**
- Full-featured CLI framework with subcommands, env var support, etc.
- Changing existing `--readeck` mode behavior
- Adding new operational modes beyond what exists
- Adding shell completions or man pages

## Decisions

### 1. Use Apple's `swift-argument-parser` package

**Choice**: Add `swift-argument-parser` as a dependency.

**Rationale**: It's Apple's official solution for Swift CLI apps, provides `--help`/`-h` out of the box, validates arguments, and produces formatted help text. The alternative — hand-rolling argument parsing — would duplicate functionality that `swift-argument-parser` handles robustly (help generation, flag parsing, error messages for unknown flags).

**Alternative considered**: Custom parsing via `CommandLine.arguments`. Rejected because it would grow complex as flags are added and wouldn't match the quality of auto-generated help text.

### 2. Refactor `Stylus` entry point to use `AsyncParsableCommand`

**Choice**: Convert `Stylus` from a bare `@main` struct with `static func main()` to a `AsyncParsableCommand` conforming type.

**Rationale**: `swift-argument-parser` requires conforming to `ParsableCommand` (or `AsyncParsableCommand` for async). The `--readeck` flag becomes a `@Flag` or `@Option` property. The `main()` function is replaced by `run() async throws`.

### 3. Keep it flat (no subcommands for now)

**Choice**: Use flags (`--readeck`) rather than subcommands (`stylus readeck`).

**Rationale**: The project has only two modes. Subcommands would be over-engineering at this stage. This matches the current interface and keeps the migration minimal.

## Risks / Trade-offs

- **New dependency** → `swift-argument-parser` is well-maintained by Apple and adds minimal overhead. Widely used in the Swift ecosystem.
- **Entry point refactor** → The `Stylus.swift` changes are mechanical but need careful testing to ensure both modes still work. Mitigated by existing test suite and the simplicity of the change.
- **Breaking change to CLI invocation** → `--readeck` behavior is preserved; `--help` is additive. Unknown flags that previously were silently ignored will now produce errors — this is an improvement, not a regression.
