export const FILE_TYPES = `
## File Types — Swift

### Test Files
A file is a TEST FILE if ANY of these are true:
- Filename ends with \`Tests.swift\` (e.g., \`CalculatorTests.swift\`)
- Filename ends with \`Test.swift\` (e.g., \`CalculatorTest.swift\`)
- File is inside a \`Tests/\` directory (e.g., \`Tests/CalculatorTests/CalculatorTests.swift\`)
- File contains \`import XCTest\` or \`import Testing\`
- File contains a class that inherits from \`XCTestCase\`
- File contains \`@Test\` or \`@Suite\` attributes (Swift Testing framework)

### Implementation Files
A file is an IMPLEMENTATION FILE if:
- It is a \`.swift\` file that does NOT match any test file pattern above.
- Examples: \`Calculator.swift\`, \`Sources/Calculator/Calculator.swift\`

### Non-Swift Files
Files that are NOT \`.swift\` files should generally be IGNORED by TDD validation:
- \`Package.swift\` is a special case — it is a manifest file, not implementation code. Changes to it should be ALLOWED.
- \`.plist\`, \`.xcconfig\`, \`.json\`, \`.yml\`, \`.md\` files are configuration/documentation and should be ALLOWED.

### Rules by File Type

**Test files:**
- RED phase: Adding ONE new test method is always allowed.
- GREEN phase: Modifying test files to fix test infrastructure is allowed.
- REFACTOR phase: Reorganizing tests while green is allowed.

**Implementation files:**
- RED phase: Modifying implementation during red is a VIOLATION (unless it's a stub needed for compilation).
- GREEN phase: Adding minimal implementation to pass the failing test is allowed.
- REFACTOR phase: Improving code while green is allowed (no new behavior).

**Package.swift / project files:**
- Always ALLOWED — these are project configuration, not implementation.
`;
