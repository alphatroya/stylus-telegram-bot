# Swift Package Commands
- Build: `swift build`
- Test: `swift test`
- Test single: `swift test --filter <test_name>`
- Run: `swift run stylus`
- Format: `swiftformat .` (or use mise: `mise exec -- swiftformat .`)
- Lint: `swiftlint lint` (or use mise: `mise exec -- swiftlint lint`)

# Code Style Guidelines
- Use Swift 6.2 with modern concurrency (target: macOS 15+)
- Format with swiftformat (mise-managed, max width 140 chars)
- Use Swift Testing framework (#expect, @Test, @Suite with descriptive names)
- Prefer guard statements over nested ifs for early returns
- Use `// MARK: - ClassName` comments for type organization
- Keep imports minimal and organized (Foundation first, then third-party)
- Use async/await for asynchronous operations, avoid completion handlers
- Prefer structs over classes, mark classes as final when inheritance not needed
- Use dependency injection for file system operations (FileWorker protocol)
- Avoid force unwrapping, use guard/if-let or nil-coalescing
- Use descriptive variable/function names (messageDateFormatted vs dateStr)
- Handle errors explicitly with do-catch, don't use try! in production code
- Use @testable import for accessing internal APIs in tests
- Prefer parameterized tests with @Test(arguments:) for multiple test cases

