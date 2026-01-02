<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Swift Package Commands
- Build: `swift build`
- Test: `swift test`
- Test single: `swift test --filter <test_name>`
- Run: `swift run stylus`
- Format: `swiftformat .` (or use mise: `mise exec -- swiftformat .`)

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

# GitHub CLI Task Tracking
- List issues: `gh issue list`
- Create issue: `gh issue create --title "Title" --body "Description"`
- View issue: `gh issue view <number>`
- Close issue: `gh issue close <number>`
- Create PR: `gh pr create --title "Title" --body "Description"`
- List PRs: `gh pr list`
