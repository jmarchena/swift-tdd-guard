export interface ValidationResult {
  decision: "block" | null;
  reason: string;
}

export interface HookData {
  hook: string;
  tool_name: string;
  tool_input: Record<string, unknown>;
}

export interface SessionEvent {
  hook: string;
  session_event?: string;
}

export interface UserPromptEvent {
  hook: string;
  user_prompt?: string;
}

export interface WriteOperation {
  tool_name: "Write";
  tool_input: {
    file_path: string;
    content: string;
  };
}

export interface EditOperation {
  tool_name: "Edit";
  tool_input: {
    file_path: string;
    old_string: string;
    new_string: string;
  };
}

export interface MultiEditOperation {
  tool_name: "MultiEdit";
  tool_input: {
    file_path: string;
    edits: Array<{ old_string: string; new_string: string }>;
  };
}

export type ToolOperation = WriteOperation | EditOperation | MultiEditOperation;

export interface TestCase {
  name: string;
  fullName: string;
  state: "passed" | "failed" | "skipped";
  errors?: string[];
}

export interface TestModule {
  moduleId: string;
  tests: TestCase[];
}

export interface TestResults {
  testModules: TestModule[];
  unhandledErrors?: string[];
  reason?: string;
}

export interface GuardConfig {
  guardEnabled: boolean;
  ignorePatterns: string[];
}

export interface LintIssue {
  file: string;
  line: number;
  column: number;
  severity: "warning" | "error";
  message: string;
  rule: string;
}

export interface LintResults {
  issues: LintIssue[];
}
