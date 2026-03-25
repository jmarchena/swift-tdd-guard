import type { GuardManager } from "../guard/GuardManager.js";
import type { ValidationResult } from "../contracts/types.js";

export function handleUserPrompt(
  prompt: string,
  guard: GuardManager
): ValidationResult | null {
  const trimmed = prompt.trim().toLowerCase();

  if (trimmed === "tdd-guard on" || trimmed === "swift-tdd-guard on") {
    guard.enable();
    return {
      decision: null,
      reason: "TDD Guard enabled.",
    };
  }

  if (trimmed === "tdd-guard off" || trimmed === "swift-tdd-guard off") {
    guard.disable();
    return {
      decision: null,
      reason: "TDD Guard disabled.",
    };
  }

  return null;
}
