export const TDD_RULES = `
## TDD Rules for Swift

### RED Phase — Write ONE Failing Test

- Adding a single test method (func test...) to a test file is ALWAYS allowed.
- The test file must follow Swift test naming conventions (see File Types below).
- Only ONE new test method at a time. Adding multiple new test methods simultaneously is a VIOLATION.
- The test should use XCTest assertions (XCTAssertEqual, XCTAssertTrue, XCTAssertNil, XCTAssertThrowsError, etc.) or Swift Testing macros (#expect, #require).
- Adding test helper methods (non-test functions inside test classes) is allowed alongside a test.
- Adding setUp/tearDown overrides is allowed alongside a test.

### GREEN Phase — Write MINIMAL Code to Pass

- Implementation is ONLY allowed when there is evidence of a failing test (test output present).
- The implementation must be MINIMAL — only enough to make the failing test pass.
- Match the implementation to the specific failure type:
  - "Use of unresolved identifier 'X'" or "Cannot find 'X' in scope" → Create an empty struct/class/enum declaration only.
  - "has no member 'X'" or "value of type 'X' has no member 'Y'" → Add a minimal member stub (property or method returning a default value).
  - "Type 'X' has no member 'Y'" → Add a static member stub.
  - Assertion failure (XCTAssertEqual got wrong value, etc.) → Implement the minimal logic to satisfy the assertion.
- Do NOT add extra methods, properties, protocol conformances, or initializers beyond what the failing test requires.
- Do NOT implement patterns (protocols, generics, extensions) unless the test specifically requires them.

### REFACTOR Phase — Improve While Green

- Refactoring is ONLY allowed when all relevant tests are PASSING.
- Requires proof that tests have been run and are green (test output present showing all pass).
- No new behavior may be introduced during refactoring.
- Allowed refactoring operations:
  - Extract protocols or extract methods
  - Rename types, methods, properties
  - Reorganize code structure (move to extensions, separate files)
  - Add/change access control modifiers (public, private, internal)
  - Add type aliases
  - Replace magic numbers with named constants
  - Simplify control flow
  - Extract shared test setup into setUp/tearDown
- NOT allowed during refactor:
  - Adding new untested functionality
  - Adding protocol conformances that introduce new behavior
  - Adding new public API surface

### Core Violations

1. **Multiple test addition** — Adding more than one new test method in a single operation.
2. **Over-implementation** — Writing more code than the minimum needed to pass the current failing test.
3. **Premature implementation** — Writing implementation code without a failing test.
4. **Refactoring with failing tests** — Modifying implementation while tests are red.
`;
