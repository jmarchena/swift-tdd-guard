import type { Config } from "../config/Config.js";
import type { FileStorage } from "../storage/FileStorage.js";
import type { ToolOperation, ValidationResult } from "../contracts/types.js";
import { SYSTEM_PROMPT } from "./prompts/system-prompt.js";
import { buildValidationContext } from "./context.js";

export async function validate(
  config: Config,
  storage: FileStorage,
  operation: ToolOperation
): Promise<ValidationResult> {
  const context = buildValidationContext(storage, operation);

  try {
    const response = await callModel(config, context);
    return parseResponse(response);
  } catch (error) {
    // On validation failure, allow the operation to avoid blocking development
    const message = error instanceof Error ? error.message : String(error);
    return {
      decision: null,
      reason: `Validation error (allowing operation): ${message}`,
    };
  }
}

async function callModel(config: Config, context: string): Promise<string> {
  // Use Claude Agent SDK
  const { query } = await import("@anthropic-ai/claude-agent-sdk");
  const result = await query({
    systemPrompt: SYSTEM_PROMPT,
    prompt: context,
    options: {
      model: config.modelVersion,
      maxTurns: 1,
    },
  });
  return result;
}

function parseResponse(response: string): ValidationResult {
  // Extract JSON from the response (handle markdown code blocks)
  let jsonStr = response.trim();

  const jsonMatch = jsonStr.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (jsonMatch) {
    jsonStr = jsonMatch[1].trim();
  }

  // Try to find a JSON object in the response
  const objMatch = jsonStr.match(/\{[\s\S]*\}/);
  if (objMatch) {
    jsonStr = objMatch[0];
  }

  const parsed = JSON.parse(jsonStr);

  if (parsed.decision === "block") {
    return { decision: "block", reason: parsed.reason ?? "TDD violation detected." };
  }

  return { decision: null, reason: parsed.reason ?? "Operation allowed." };
}
