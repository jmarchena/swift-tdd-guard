# swift-tdd-guard

A TDD enforcement tool for Swift development with [Claude Code](https://claude.ai/code). Adapted from [tdd-guard](https://github.com/nizos/tdd-guard) by Nizar Selander.

When Claude Code writes or edits Swift files, swift-tdd-guard intercepts the operation, validates it against strict TDD principles using AI, and blocks changes that violate the Red-Green-Refactor cycle.

## How It Works

swift-tdd-guard uses Claude Code's **hook system** to intercept file operations in real time:

```
Claude Code proposes a file change
        ↓
PreToolUse hook fires → swift-tdd-guard receives the operation via stdin
        ↓
Validates against TDD rules (AI-powered)
        ↓
Returns {"decision": "block", "reason": "..."} or allows the change
        ↓
PostToolUse hook fires → runs SwiftLint on modified files
```

### The Validation Pipeline

1. **Hook intercept** — Claude Code pipes the proposed operation (tool name, file path, content) as JSON to `swift-tdd-guard` via stdin.
2. **File filtering** — Non-Swift files and ignored patterns (`.json`, `.md`, `.plist`, etc.) pass through without validation.
3. **Context assembly** — The validator collects the current operation, latest test results (from `test.json`), lint results, and custom instructions into a single prompt.
4. **AI validation** — The assembled context is sent to Claude (via the Agent SDK) along with the TDD rules. The AI determines whether the change follows TDD discipline.
5. **Decision** — The AI returns a JSON verdict: `"allow"` or `"block"` with a reason. If blocked, Claude Code receives the reason and must adjust its approach.

### State Between Operations

swift-tdd-guard maintains state between hook invocations via JSON files in `.claude/tdd-guard/data/`:

| File | Purpose |
|------|---------|
| `test.json` | Latest XCTest results (written by the reporter) |
| `modifications.json` | The current proposed operation |
| `config.json` | Guard enabled/disabled state and ignore patterns |
| `lint.json` | Latest SwiftLint results |
| `instructions.md` | Customizable TDD rules (editable by the user) |

This state is **transient** — it is cleared on session start (startup, resume, or clear) so each Claude Code session begins fresh.

## The TDD Cycle

swift-tdd-guard enforces three strict phases:

### RED — Write ONE Failing Test

- Adding a single `func test...` method to a test file is **always allowed**.
- Only **one** new test method at a time. Multiple new tests in one operation = violation.
- Test helpers, `setUp`/`tearDown`, and imports alongside the test are fine.

### GREEN — Write MINIMAL Code to Pass

- Implementation is **only allowed** when there is evidence of a failing test (test output present in `test.json`).
- The implementation must be **minimal** — exactly what the failing test demands:

| Test Failure | Allowed Implementation |
|---|---|
| `Cannot find 'Calculator' in scope` | Empty `struct Calculator {}` |
| `has no member 'add'` | Method stub: `func add(_ a: Int, _ b: Int) -> Int { 0 }` |
| `XCTAssertEqual failed: (0) != (5)` | Minimal logic to return the correct value |

- No extra methods, properties, protocol conformances, or initializers beyond what the test requires.
- No anticipatory patterns (protocols, generics, extensions) unless the test specifically needs them.

### REFACTOR — Improve While Green

- Only allowed when **all tests are passing**.
- No new behavior — only structural improvements:
  - Extract protocols/methods, rename, reorganize into extensions
  - Add access control, type aliases, named constants
  - Simplify control flow, extract shared test setup
- Adding new untested functionality during refactor = violation.

### Core Violations Detected

| Violation | Example |
|---|---|
| **Multiple test addition** | Adding `testAdd()` and `testSubtract()` in one operation |
| **Over-implementation** | Test says "Cannot find Calculator" but code adds class + methods |
| **Premature implementation** | Writing `Calculator.swift` before any test exists |
| **Refactoring with failing tests** | Renaming methods while a test is red |

## Architecture

```
swift-tdd-guard/
├── src/                          # TypeScript — Claude Code hook logic
│   ├── cli/tdd-guard.ts          # Entry point (reads stdin, writes stdout)
│   ├── config/Config.ts          # Configuration from env vars
│   ├── contracts/types.ts        # All TypeScript interfaces
│   ├── guard/GuardManager.ts     # Enable/disable toggle, ignore patterns
│   ├── hooks/
│   │   ├── processHookData.ts    # Central orchestrator
│   │   ├── sessionHandler.ts     # Session initialization
│   │   └── userPromptHandler.ts  # "tdd-guard on/off" commands
│   ├── linters/SwiftLint.ts      # SwiftLint integration
│   ├── storage/FileStorage.ts    # JSON file persistence
│   └── validation/
│       ├── context.ts            # Assembles the AI prompt
│       ├── validator.ts          # Calls Claude, parses response
│       └── prompts/
│           ├── system-prompt.ts  # AI role definition
│           ├── rules.ts          # TDD rules for Swift
│           ├── file-types.ts     # Test vs implementation detection
│           └── response.ts       # Expected JSON format
├── reporter/                     # Swift package — XCTest reporter
│   ├── Package.swift
│   └── Sources/TDDGuardReporter/
│       ├── TDDGuardObserver.swift # XCTestObservation implementation
│       ├── AutoRegister.swift     # Automatic observer registration
│       └── TestResult.swift       # Codable JSON models
└── plugin/
    ├── hooks/hooks.json          # Claude Code hook registration
    └── skills/setup/SKILL.md     # Setup guide
```

### Design Decisions

#### Why TypeScript for the hook logic?

Claude Code hooks execute shell commands. The standard pattern is `npx <package>`, which works naturally with npm. The original tdd-guard uses this approach, and it provides the simplest integration with Claude Code's hook system. The hook logic doesn't need to be in Swift — it's infrastructure, not application code.

#### Why a separate Swift package for the reporter?

The reporter must integrate with XCTest's observation API (`XCTestObservation`), which is a Swift/Objective-C framework. It runs inside the test process and writes results to a JSON file that the hook logic reads. This is the same architecture tdd-guard uses for its Vitest/Jest/pytest reporters.

#### Why AI-powered validation instead of static rules?

TDD compliance is context-dependent. A static rule engine would need to parse Swift AST, understand test semantics, and reason about "minimal implementation" — which is fundamentally a judgment call. Using an AI model (Claude Sonnet by default) allows nuanced validation: it can understand that `struct Calculator {}` is minimal for "Cannot find Calculator" but over-implementation for "has no member add".

#### Why fail open?

If the AI validation fails (network error, timeout, SDK issue), the operation is **allowed** rather than blocked. Blocking a developer's work due to infrastructure failure would be worse than missing a TDD violation. The error is logged in the reason field for transparency.

#### What was dropped from the original tdd-guard?

| Original Feature | Decision | Reason |
|---|---|---|
| Multi-language support (Python, PHP, Go, Rust, JS) | Dropped | Swift-only focus |
| Multiple reporters (Vitest, Jest, pytest, PHPUnit, Go, Rust, Storybook) | Dropped | Only XCTest needed |
| Multiple AI clients (SDK, API, CLI) | Dropped | SDK is the default and most reliable |
| ESLint / golangci-lint | Replaced | SwiftLint is the Swift standard |
| Todo tracking | Dropped | Minor feature, not core to TDD enforcement |
| Plugin marketplace registration | Dropped | Manual setup is sufficient for now |
| Multiple model client providers | Dropped | Single SDK client keeps it simple |

## Installation

### Prerequisites

- Node.js 18+
- Claude Code CLI
- Xcode / Swift toolchain
- SwiftLint (optional, for refactor-phase linting)

### 1. Install the hook

```bash
npm install -g swift-tdd-guard
```

### 2. Configure Claude Code hooks

Add to your project's `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [{ "type": "command", "command": "npx swift-tdd-guard@latest" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [{ "type": "command", "command": "npx swift-tdd-guard@latest" }]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [{ "type": "command", "command": "npx swift-tdd-guard@latest" }]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [{ "type": "command", "command": "npx swift-tdd-guard@latest" }]
      }
    ]
  }
}
```

### 3. Add the XCTest reporter

For Swift Package Manager projects, add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_USER/swift-tdd-guard", from: "0.1.0"),
],
targets: [
    .testTarget(
        name: "YourProjectTests",
        dependencies: [
            "YourProject",
            .product(name: "TDDGuardReporter", package: "swift-tdd-guard"),
        ]
    ),
]
```

Then register the observer in your test target:

```swift
import TDDGuardReporter

// Option A: Auto-register (add once to any file in your test target)
private let _register: Void = {
    TDDGuardAutoRegister.register()
}()

// Option B: Manual registration
// XCTestObservationCenter.shared.addTestObserver(TDDGuardObserver())
```

### 4. Install SwiftLint (optional)

```bash
brew install swiftlint
```

SwiftLint violations are checked during the refactor phase — if tests are green but lint errors exist, the guard blocks further changes until lint is fixed.

## Usage

### Enable/Disable

Type in Claude Code's prompt:

```
tdd-guard on    # Enable TDD enforcement
tdd-guard off   # Disable TDD enforcement
```

The guard is **enabled by default** on session start.

### Typical Session Flow

1. **Session starts** → guard initializes, clears previous state
2. **You ask Claude to add a feature** → Claude writes a test first
3. **PreToolUse fires** → guard validates: "Adding single test to test file" → ALLOWED
4. **Claude runs the test** → reporter writes results to `test.json` (test fails)
5. **Claude writes implementation** → guard validates against the specific failure → ALLOWED or BLOCKED
6. **Claude runs tests again** → reporter updates `test.json` (test passes)
7. **Claude refactors** → guard checks tests are green, validates no new behavior → ALLOWED

### Configuration

| Environment Variable | Default | Purpose |
|---|---|---|
| `CLAUDE_PROJECT_DIR` | `.claude/tdd-guard/data` | Data directory for state files |
| `TDD_GUARD_MODEL_VERSION` | `claude-sonnet-4-20250514` | Model used for validation |
| `TDD_GUARD_ANTHROPIC_API_KEY` | — | API key (if not using Claude Code auth) |
| `TDD_GUARD_TEST_OUTPUT` | `.claude/tdd-guard/data/test.json` | Reporter output path |

### Custom Instructions

Edit `.claude/tdd-guard/data/instructions.md` to customize the TDD rules. This file is included in the AI validation context and can override or extend the default rules.

## Test File Detection

swift-tdd-guard identifies test files by these patterns:

- Filename ends with `Tests.swift` or `Test.swift`
- File is inside a `Tests/` directory
- File contains `import XCTest` or `import Testing`
- File contains a class inheriting from `XCTestCase`
- File contains `@Test` or `@Suite` attributes (Swift Testing)

Everything else with a `.swift` extension is treated as an implementation file. `Package.swift` and non-Swift files are always allowed through.

## Ignored Files

By default, these file patterns skip validation entirely:

```
*.md, *.txt, *.log, *.json, *.yml, *.yaml, *.xml,
*.html, *.css, *.plist, *.pbxproj, *.xcscheme,
*.xcworkspacedata, Package.resolved
```

## Credits

This project is adapted from [tdd-guard](https://github.com/nizos/tdd-guard) by [Nizar Selander](https://github.com/nizos), which enforces TDD discipline for JavaScript/TypeScript, Python, PHP, Go, and Rust projects with Claude Code.

## License

MIT
