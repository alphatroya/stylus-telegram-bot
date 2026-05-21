## ADDED Requirements

### Requirement: Help flag support
The system SHALL display usage information when invoked with `--help` or `-h` and exit with code 0. The help output SHALL list all available flags, their descriptions, and the available modes (default Telegram mode, Readeck sync mode).

#### Scenario: User passes --help
- **WHEN** the CLI is invoked with `--help`
- **THEN** the system SHALL print usage information to stdout and exit with code 0

#### Scenario: User passes -h
- **WHEN** the CLI is invoked with `-h`
- **THEN** the system SHALL print usage information to stdout and exit with code 0

### Requirement: Structured argument parsing
The system SHALL use `swift-argument-parser` to parse command-line arguments via `AsyncParsableCommand` conformance. The `--readeck` flag SHALL be defined as a `@Flag` property on the command struct.

#### Scenario: Readeck flag parsed correctly
- **WHEN** the CLI is invoked with `--readeck`
- **THEN** the readeck flag property SHALL be `true` and the system SHALL activate Readeck sync mode

#### Scenario: No flags provided
- **WHEN** the CLI is invoked with no arguments
- **THEN** the system SHALL run in default Telegram bot mode

### Requirement: Unknown flag error handling
The system SHALL exit with a non-zero exit code and display an error message when invoked with unrecognized flags. The error message SHALL suggest running `--help` for usage information.

#### Scenario: Unrecognized flag
- **WHEN** the CLI is invoked with `--unknown-flag`
- **THEN** the system SHALL print an error message to stderr and exit with a non-zero code

### Requirement: Help output content
The help output SHALL include: the executable name (`stylus`), a brief description of the tool, a list of all available flags with short descriptions, and usage examples.

#### Scenario: Help output contains flag descriptions
- **WHEN** `--help` is invoked
- **THEN** the output SHALL include `--readeck` with a description of Readeck sync mode
