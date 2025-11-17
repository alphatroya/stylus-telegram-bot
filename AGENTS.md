# Swift Package Commands
- Build: `swift build`
- Test: `swift test`
- Test single: `swift test --filter <test_name>`
- Run: `swift run`

# Code Style Guidelines
- Use Swift 6.2 with modern concurrency
- Format with swiftformat (mise-managed)
- Use Swift Testing framework (#expect, @Test, @Suite)
- Prefer guard statements over nested ifs
- Use MARK: comments for code organization
- Keep imports organized and minimal
- Use async/await for asynchronous operations
- Prefer final classes and value types
- Avoid force unwrapping in tests
- Use descriptive variable and function names