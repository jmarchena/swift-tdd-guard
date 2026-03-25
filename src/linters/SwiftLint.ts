import { execSync } from "node:child_process";
import type { LintResults, LintIssue } from "../contracts/types.js";

export async function runSwiftLint(filePath: string): Promise<LintResults> {
  try {
    const output = execSync(
      `swiftlint lint --path "${filePath}" --reporter json --quiet`,
      {
        encoding: "utf-8",
        timeout: 30_000,
        stdio: ["pipe", "pipe", "pipe"],
      }
    );

    const parsed = JSON.parse(output || "[]") as SwiftLintViolation[];
    const issues: LintIssue[] = parsed.map((v) => ({
      file: v.file,
      line: v.line,
      column: v.character,
      severity: v.severity === "error" ? "error" : "warning",
      message: v.reason,
      rule: v.rule_id,
    }));

    return { issues };
  } catch (error) {
    // SwiftLint returns exit code 2 when there are violations but still outputs JSON
    if (error && typeof error === "object" && "stdout" in error) {
      const stdout = (error as { stdout: string }).stdout;
      if (stdout) {
        try {
          const parsed = JSON.parse(stdout) as SwiftLintViolation[];
          const issues: LintIssue[] = parsed.map((v) => ({
            file: v.file,
            line: v.line,
            column: v.character,
            severity: v.severity === "error" ? "error" : "warning",
            message: v.reason,
            rule: v.rule_id,
          }));
          return { issues };
        } catch {
          // JSON parse failed
        }
      }
    }
    throw error;
  }
}

interface SwiftLintViolation {
  file: string;
  line: number;
  character: number;
  severity: string;
  reason: string;
  rule_id: string;
  type: string;
}
