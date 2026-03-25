import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import type {
  TestResults,
  GuardConfig,
  LintResults,
  ToolOperation,
} from "../contracts/types.js";

const FILES = {
  test: "test.json",
  modifications: "modifications.json",
  config: "config.json",
  lint: "lint.json",
  instructions: "instructions.md",
} as const;

export class FileStorage {
  constructor(private readonly dataDir: string) {
    this.ensureDir();
  }

  private ensureDir(): void {
    if (!existsSync(this.dataDir)) {
      mkdirSync(this.dataDir, { recursive: true });
    }
  }

  private path(file: string): string {
    return join(this.dataDir, file);
  }

  private readJson<T>(file: string): T | null {
    const filePath = this.path(file);
    if (!existsSync(filePath)) return null;
    try {
      return JSON.parse(readFileSync(filePath, "utf-8")) as T;
    } catch {
      return null;
    }
  }

  private writeJson(file: string, data: unknown): void {
    const filePath = this.path(file);
    mkdirSync(dirname(filePath), { recursive: true });
    writeFileSync(filePath, JSON.stringify(data, null, 2));
  }

  private deleteFile(file: string): void {
    const filePath = this.path(file);
    if (existsSync(filePath)) {
      const { unlinkSync } = require("node:fs");
      unlinkSync(filePath);
    }
  }

  getTestResults(): TestResults | null {
    return this.readJson<TestResults>(FILES.test);
  }

  getModifications(): ToolOperation | null {
    return this.readJson<ToolOperation>(FILES.modifications);
  }

  saveModifications(op: ToolOperation): void {
    this.writeJson(FILES.modifications, op);
  }

  getGuardConfig(): GuardConfig {
    return (
      this.readJson<GuardConfig>(FILES.config) ?? {
        guardEnabled: true,
        ignorePatterns: DEFAULT_IGNORE_PATTERNS,
      }
    );
  }

  saveGuardConfig(config: GuardConfig): void {
    this.writeJson(FILES.config, config);
  }

  getLintResults(): LintResults | null {
    return this.readJson<LintResults>(FILES.lint);
  }

  saveLintResults(results: LintResults): void {
    this.writeJson(FILES.lint, results);
  }

  getInstructions(): string | null {
    const filePath = this.path(FILES.instructions);
    if (!existsSync(filePath)) return null;
    return readFileSync(filePath, "utf-8");
  }

  saveInstructions(content: string): void {
    writeFileSync(this.path(FILES.instructions), content);
  }

  clearTransientData(): void {
    this.deleteFile(FILES.test);
    this.deleteFile(FILES.modifications);
    this.deleteFile(FILES.lint);
  }
}

const DEFAULT_IGNORE_PATTERNS = [
  "*.md",
  "*.txt",
  "*.log",
  "*.json",
  "*.yml",
  "*.yaml",
  "*.xml",
  "*.html",
  "*.css",
  "*.plist",
  "*.pbxproj",
  "*.xcscheme",
  "*.xcworkspacedata",
  "Package.resolved",
];
