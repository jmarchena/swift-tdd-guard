import type { FileStorage } from "../storage/FileStorage.js";

export class GuardManager {
  constructor(private readonly storage: FileStorage) {}

  isEnabled(): boolean {
    return this.storage.getGuardConfig().guardEnabled;
  }

  enable(): void {
    const config = this.storage.getGuardConfig();
    config.guardEnabled = true;
    this.storage.saveGuardConfig(config);
  }

  disable(): void {
    const config = this.storage.getGuardConfig();
    config.guardEnabled = false;
    this.storage.saveGuardConfig(config);
  }

  shouldIgnore(filePath: string): boolean {
    const config = this.storage.getGuardConfig();
    return config.ignorePatterns.some((pattern) =>
      matchGlob(pattern, filePath)
    );
  }
}

function matchGlob(pattern: string, filePath: string): boolean {
  const fileName = filePath.split("/").pop() ?? filePath;

  if (pattern.startsWith("*.")) {
    const ext = pattern.slice(1);
    return fileName.endsWith(ext);
  }

  return fileName === pattern;
}
