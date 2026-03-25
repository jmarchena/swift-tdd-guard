import type { Config } from "../config/Config.js";
import type { FileStorage } from "../storage/FileStorage.js";
import { GuardManager } from "../guard/GuardManager.js";
import type {
  ValidationResult,
  HookData,
  ToolOperation,
} from "../contracts/types.js";
import { handleSessionStart } from "./sessionHandler.js";
import { handleUserPrompt } from "./userPromptHandler.js";
import { validate } from "../validation/validator.js";
import { runSwiftLint } from "../linters/SwiftLint.js";

export async function processHookData(
  rawData: unknown,
  config: Config,
  storage: FileStorage
): Promise<ValidationResult> {
  const data = rawData as Record<string, unknown>;
  const hook = data.hook as string | undefined;
  const guard = new GuardManager(storage);

  // Handle session start
  if (hook === "SessionStart") {
    handleSessionStart(storage);
    return { decision: null, reason: "Session initialized." };
  }

  // Handle user prompt (on/off toggle)
  if (hook === "UserPromptSubmit") {
    const prompt = data.user_prompt as string | undefined;
    if (prompt) {
      const result = handleUserPrompt(prompt, guard);
      if (result) return result;
    }
    return { decision: null, reason: "" };
  }

  // Check if guard is disabled
  if (!guard.isEnabled()) {
    return { decision: null, reason: "TDD Guard is disabled." };
  }

  // Must be PreToolUse or PostToolUse at this point
  const toolName = data.tool_name as string | undefined;
  const toolInput = data.tool_input as Record<string, unknown> | undefined;

  if (!toolName || !toolInput) {
    return { decision: null, reason: "No tool operation to validate." };
  }

  // Check if file should be ignored
  const filePath = toolInput.file_path as string | undefined;
  if (filePath && guard.shouldIgnore(filePath)) {
    return { decision: null, reason: "File type is ignored by TDD Guard." };
  }

  // Only validate Swift files
  if (filePath && !filePath.endsWith(".swift")) {
    return { decision: null, reason: "Not a Swift file, skipping validation." };
  }

  // Handle PostToolUse — run SwiftLint after modifications
  if (hook === "PostToolUse") {
    if (filePath) {
      try {
        const lintResults = await runSwiftLint(filePath);
        storage.saveLintResults(lintResults);
      } catch {
        // SwiftLint not available or failed — continue without lint
      }
    }
    return { decision: null, reason: "Post-tool processing complete." };
  }

  // PreToolUse — validate the operation
  const operation = {
    tool_name: toolName,
    tool_input: toolInput,
  } as ToolOperation;

  // Save the current operation
  storage.saveModifications(operation);

  // Check for lint issues before allowing new changes (if tests are green)
  const testResults = storage.getTestResults();
  const lintResults = storage.getLintResults();
  if (testResults && lintResults && lintResults.issues.length > 0) {
    const allPassing = testResults.testModules.every((mod) =>
      mod.tests.every((t) => t.state === "passed" || t.state === "skipped")
    );
    if (allPassing) {
      const errorCount = lintResults.issues.filter(
        (i) => i.severity === "error"
      ).length;
      if (errorCount > 0) {
        return {
          decision: "block",
          reason: `SwiftLint has ${errorCount} error(s). Fix lint issues before making new changes.`,
        };
      }
    }
  }

  // Perform AI validation
  return validate(config, storage, operation);
}
