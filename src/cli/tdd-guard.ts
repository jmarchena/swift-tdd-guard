#!/usr/bin/env node

import { Config } from "../config/Config.js";
import { FileStorage } from "../storage/FileStorage.js";
import { processHookData } from "../hooks/processHookData.js";

async function main(): Promise<void> {
  const input = await readStdin();

  if (!input) {
    process.stdout.write(JSON.stringify({ decision: null, reason: "No input." }));
    return;
  }

  let data: unknown;
  try {
    data = JSON.parse(input);
  } catch {
    process.stdout.write(
      JSON.stringify({ decision: null, reason: "Invalid JSON input." })
    );
    return;
  }

  const config = new Config();
  const storage = new FileStorage(config.dataDir);

  const result = await processHookData(data, config, storage);

  // Format output for Claude Code hooks
  const output: Record<string, unknown> = {};

  if (result.decision === "block") {
    output.decision = "block";
    output.reason = result.reason;
  }

  // Only output if there is something to communicate
  if (Object.keys(output).length > 0) {
    process.stdout.write(JSON.stringify(output));
  }
}

function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    let data = "";
    process.stdin.setEncoding("utf-8");
    process.stdin.on("data", (chunk) => (data += chunk));
    process.stdin.on("end", () => resolve(data.trim()));

    // Handle case where stdin is not being piped
    if (process.stdin.isTTY) {
      resolve("");
    }
  });
}

main().catch((error) => {
  // Never crash — output error as reason and allow the operation
  process.stdout.write(
    JSON.stringify({
      decision: null,
      reason: `Guard error: ${error instanceof Error ? error.message : String(error)}`,
    })
  );
});
