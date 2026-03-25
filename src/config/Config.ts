export interface ConfigOptions {
  dataDir?: string;
  modelVersion?: string;
  anthropicApiKey?: string;
}

export class Config {
  readonly dataDir: string;
  readonly modelVersion: string;
  readonly anthropicApiKey: string;

  constructor(options: ConfigOptions = {}) {
    this.dataDir =
      options.dataDir ??
      process.env.CLAUDE_PROJECT_DIR ??
      ".claude/tdd-guard/data";

    this.modelVersion =
      options.modelVersion ??
      process.env.TDD_GUARD_MODEL_VERSION ??
      "claude-sonnet-4-20250514";

    this.anthropicApiKey =
      options.anthropicApiKey ??
      process.env.TDD_GUARD_ANTHROPIC_API_KEY ??
      "";
  }
}
