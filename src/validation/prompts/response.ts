export const RESPONSE_FORMAT = `
## Response Format

Respond with a JSON object containing exactly these fields:

\`\`\`json
{
  "decision": "allow" | "block",
  "reason": "Brief explanation (1-2 sentences)"
}
\`\`\`

Examples:

ALLOW — Adding a single test:
\`\`\`json
{"decision": "allow", "reason": "Adding a single test method to test file — follows TDD red phase."}
\`\`\`

BLOCK — Multiple tests:
\`\`\`json
{"decision": "block", "reason": "Multiple test addition violation — adding 2 new test methods simultaneously. Write and run only ONE test at a time."}
\`\`\`

BLOCK — Over-implementation:
\`\`\`json
{"decision": "block", "reason": "Over-implementation violation. Test fails with 'Cannot find Calculator in scope' but implementation adds class with methods. Create only an empty struct/class first."}
\`\`\`

BLOCK — No failing test:
\`\`\`json
{"decision": "block", "reason": "Premature implementation — writing implementation code without a failing test. Write the test first."}
\`\`\`

ALLOW — Minimal implementation:
\`\`\`json
{"decision": "allow", "reason": "Minimal implementation to resolve 'has no member add' — adds stub method returning default value."}
\`\`\`
`;
