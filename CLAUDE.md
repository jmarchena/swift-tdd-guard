# swift-tdd-guard

TDD enforcement tool for Swift development with Claude Code.

## Project Structure

- `src/` — TypeScript source for the Claude Code hook
  - `cli/` — CLI entry point (reads stdin, writes stdout)
  - `config/` — Configuration from environment variables
  - `contracts/` — TypeScript types and interfaces
  - `guard/` — Guard enable/disable logic
  - `hooks/` — Hook event handlers (session, prompt, pre/post tool)
  - `linters/` — SwiftLint integration
  - `storage/` — File-based state persistence
  - `validation/` — AI validation engine and prompts
- `reporter/` — Swift package (XCTest observer that writes test results)
- `plugin/` — Claude Code hook configuration

## Build

```bash
npm install
npm run build
```

## How It Works

1. Claude Code hooks intercept Write/Edit/MultiEdit operations
2. Hook data is piped to `swift-tdd-guard` via stdin
3. The tool validates the operation against TDD rules using AI
4. Returns `{"decision": "block", "reason": "..."}` or empty JSON to allow
