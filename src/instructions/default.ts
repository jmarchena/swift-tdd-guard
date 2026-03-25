export const DEFAULT_INSTRUCTIONS = `# TDD Guard — Swift Instructions

Follow strict Test-Driven Development when writing Swift code:

1. **RED** — Write ONE failing test, then run it to see it fail.
2. **GREEN** — Write the MINIMAL implementation to make that test pass.
3. **REFACTOR** — Clean up code while keeping all tests green.

## Key Rules

- Always run tests after each change.
- Never write implementation code without a failing test.
- One test at a time — do not batch multiple new tests.
- Implementation must be minimal — only what the current test demands.
- Refactoring requires all tests to be green first.
- Use XCTest (XCTAssertEqual, etc.) or Swift Testing (#expect, #require).
`;
