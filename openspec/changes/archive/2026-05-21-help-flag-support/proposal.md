## Why

Stylus currently uses raw `CommandLine.arguments.contains("--readeck")` to handle CLI flags with no discovery mechanism. Users have no way to learn about available flags or usage patterns without reading source code. Adding `--help`/`-h` support provides a standard CLI interface that documents all options upfront.

## What Changes

- Add `--help` and `-h` flag support that prints usage information and exits
- Introduce structured argument parsing to replace ad-hoc `CommandLine.arguments.contains()` calls
- Display current flags (`--readeck`) and a brief description of the bot's modes in help output
- Print help automatically on unrecognized flags

## Capabilities

### New Capabilities
- `cli-arguments`: Structured command-line argument parsing, help text generation, and flag validation for the stylus executable

### Modified Capabilities

## Impact

- **Source files**: `Sources/stylus/Stylus.swift` (main entry point — argument parsing logic)
- **Dependencies**: Potentially a new dependency for argument parsing (e.g., `swift-argument-parser`), or a lightweight custom solution
- **CLI interface**: New `--help`/`-h` output; existing `--readeck` behavior unchanged
- **Tests**: New test coverage for argument parsing and help output
