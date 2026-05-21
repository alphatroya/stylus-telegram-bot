## 1. Add swift-argument-parser dependency

- [x] 1.1 Add `swift-argument-parser` package dependency to `Package.swift` (url: `https://github.com/apple/swift-argument-parser`, from: `1.5.0`)
- [x] 1.2 Add `ArgumentParser` product dependency to the `stylus` executable target

## 2. Refactor Stylus entry point

- [x] 2.1 Convert `Stylus` struct to conform to `AsyncParsableCommand` with `@main` attribute
- [x] 2.2 Add `static let configuration = CommandConfiguration(...)` with tool name `stylus` and brief description
- [x] 2.3 Add `@Flag(name: .shortAndLong, help: "Run Readeck sync mode") var readeck: Bool = false` property
- [x] 2.4 Replace `static func main()` with `func run() async throws` using the `readeck` property instead of `CommandLine.arguments.contains("--readeck")`
- [x] 2.5 Remove the `@main` struct wrapper if `AsyncParsableCommand` provides its own entry point

## 3. Verify and test

- [x] 3.1 Run `swift build` to confirm the project compiles with the new dependency
- [x] 3.2 Run `swift run stylus --help` and verify help output shows `--readeck` flag and description
- [x] 3.3 Run `swift run stylus -h` and verify short flag works identically
- [x] 3.4 Run `swift run stylus --unknown-flag` and verify error message and non-zero exit code
- [x] 3.5 Run `swift test` to confirm existing tests pass
- [x] 3.6 Add test for `--help` flag producing expected output containing `--readeck`
