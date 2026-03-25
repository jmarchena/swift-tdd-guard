# Setup Swift TDD Guard

This skill configures your Swift project to work with TDD Guard.

## Steps

1. **Detect test framework** — Check if the project uses XCTest or Swift Testing.
2. **Install the reporter** — Add the TDD Guard XCTest reporter to the test target.
3. **Configure hooks** — Copy the hook configuration to `.claude/settings.json`.
4. **Verify SwiftLint** — Check if SwiftLint is installed and accessible.

## Instructions

Run the following steps:

### 1. Check Project Structure

Look for `Package.swift` or `.xcodeproj` to determine the project type.

### 2. Add Reporter Dependency

For Swift Package Manager projects, add to `Package.swift`:

```swift
.package(url: "https://github.com/YOUR_USER/swift-tdd-guard", from: "0.1.0")
```

And add `TDDGuardReporter` to your test target dependencies.

### 3. Configure Claude Code Hooks

Add the following to your project's `.claude/settings.json`:

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

### 4. Verify SwiftLint

Run `swiftlint version` to check if SwiftLint is installed. If not, recommend:

```bash
brew install swiftlint
```
