import type { FileStorage } from "../storage/FileStorage.js";
import type { ToolOperation } from "../contracts/types.js";
import { TDD_RULES } from "./prompts/rules.js";
import { FILE_TYPES } from "./prompts/file-types.js";
import { RESPONSE_FORMAT } from "./prompts/response.js";

export function buildValidationContext(
  storage: FileStorage,
  operation: ToolOperation
): string {
  const parts: string[] = [];

  parts.push(TDD_RULES);
  parts.push(FILE_TYPES);

  // Current operation
  parts.push("## Current Operation\n");
  parts.push(`Tool: ${operation.tool_name}`);
  parts.push(`File: ${operation.tool_input.file_path}`);

  if (operation.tool_name === "Write") {
    parts.push(`\nContent being written:\n\`\`\`swift\n${operation.tool_input.content}\n\`\`\``);
  } else if (operation.tool_name === "Edit") {
    parts.push(`\nOld code:\n\`\`\`swift\n${operation.tool_input.old_string}\n\`\`\``);
    parts.push(`\nNew code:\n\`\`\`swift\n${operation.tool_input.new_string}\n\`\`\``);
  } else if (operation.tool_name === "MultiEdit") {
    for (const edit of operation.tool_input.edits) {
      parts.push(`\nOld code:\n\`\`\`swift\n${edit.old_string}\n\`\`\``);
      parts.push(`New code:\n\`\`\`swift\n${edit.new_string}\n\`\`\``);
    }
  }

  // Test results
  const testResults = storage.getTestResults();
  if (testResults) {
    parts.push("\n## Latest Test Output\n");
    for (const mod of testResults.testModules) {
      parts.push(`Module: ${mod.moduleId}`);
      for (const test of mod.tests) {
        const icon = test.state === "passed" ? "PASS" : test.state === "failed" ? "FAIL" : "SKIP";
        parts.push(`  [${icon}] ${test.fullName}`);
        if (test.errors?.length) {
          for (const err of test.errors) {
            parts.push(`    Error: ${err}`);
          }
        }
      }
    }
    if (testResults.unhandledErrors?.length) {
      parts.push("\nUnhandled errors:");
      for (const err of testResults.unhandledErrors) {
        parts.push(`  ${err}`);
      }
    }
  } else {
    parts.push("\n## Latest Test Output\n");
    parts.push("No test results available. Tests have not been run yet.");
  }

  // Lint results
  const lintResults = storage.getLintResults();
  if (lintResults && lintResults.issues.length > 0) {
    parts.push("\n## SwiftLint Issues\n");
    for (const issue of lintResults.issues) {
      parts.push(
        `${issue.file}:${issue.line}:${issue.column} ${issue.severity}: ${issue.message} (${issue.rule})`
      );
    }
  }

  // Custom instructions
  const instructions = storage.getInstructions();
  if (instructions) {
    parts.push("\n## Custom Instructions\n");
    parts.push(instructions);
  }

  parts.push(RESPONSE_FORMAT);

  return parts.join("\n");
}
