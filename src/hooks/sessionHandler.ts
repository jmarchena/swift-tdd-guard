import type { FileStorage } from "../storage/FileStorage.js";

const DEFAULT_INSTRUCTIONS = `# TDD Guard — Swift Instructions

Follow strict Test-Driven Development when writing Swift code:

1. **RED** — Write ONE failing test, then run it to see it fail.
2. **GREEN** — Write the MINIMAL implementation to make that test pass.
3. **REFACTOR** — Clean up code while keeping all tests green.

## Running Tests

ALWAYS run tests using \`tdd-guard-swift-test\` instead of \`swift test\`:

\`\`\`bash
tdd-guard-swift-test
\`\`\`

This wrapper captures results from both XCTest and Swift Testing and writes
them to \`.claude/tdd-guard/data/test.json\` so the guard can validate your
next move. Running \`swift test\` directly bypasses result tracking.

You can pass extra arguments the same way as \`swift test\`:
\`\`\`bash
tdd-guard-swift-test --filter CalculatorTests
\`\`\`

If \`tdd-guard-swift-test\` is not found, remind the user to build and install
the reporter binary from the \`reporter/\` directory:
\`\`\`bash
cd reporter && swift build -c release
cp .build/release/tdd-guard-swift-test /usr/local/bin/
\`\`\`
`;

export function handleSessionStart(storage: FileStorage): void {
  // Clear transient data for a fresh session
  storage.clearTransientData();

  // Ensure default instructions exist
  if (!storage.getInstructions()) {
    storage.saveInstructions(DEFAULT_INSTRUCTIONS);
  }
}
