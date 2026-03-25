import type { FileStorage } from "../storage/FileStorage.js";

const DEFAULT_INSTRUCTIONS = `# TDD Guard — Swift Instructions

Follow strict Test-Driven Development when writing Swift code:

1. **RED** — Write ONE failing test, then run it to see it fail.
2. **GREEN** — Write the MINIMAL implementation to make that test pass.
3. **REFACTOR** — Clean up code while keeping all tests green.

Always run tests after each change. Do not skip ahead.
`;

export function handleSessionStart(storage: FileStorage): void {
  // Clear transient data for a fresh session
  storage.clearTransientData();

  // Ensure default instructions exist
  if (!storage.getInstructions()) {
    storage.saveInstructions(DEFAULT_INSTRUCTIONS);
  }
}
