import Foundation

/// Parses `swift test` console output into the tdd-guard JSON schema.
///
/// Works with both XCTest and Swift Testing output formats:
///
/// XCTest output:
///   Test Case '-[ModuleTests.CalculatorTests testAdd]' passed (0.001 seconds).
///   Test Case '-[ModuleTests.CalculatorTests testFail]' failed (0.002 seconds).
///   /path/file.swift:10: error: ... XCTAssertEqual failed: ("0") != ("5")
///
/// Swift Testing output:
///   ✔ Test "add()" passed after 0.001 seconds.
///   ✘ Test "subtract()" failed after 0.002 seconds with 1 issue.
///   ↳ CalculatorTests/subtract():15: Expectation failed: (result → 0) == (5)
///
/// Also handles `swift test --experimental-event-stream-output` JSON events.
struct SwiftTestOutputParser {

    struct TestCaseResult: Codable {
        let name: String
        let fullName: String
        let state: String
        let errors: [String]?
    }

    struct TestModuleResult: Codable {
        let moduleId: String
        let tests: [TestCaseResult]
    }

    struct TestRunOutput: Codable {
        let testModules: [TestModuleResult]
        let unhandledErrors: [String]?
        let reason: String?
    }

    func parse(_ output: String) -> TestRunOutput {
        if let jsonResult = parseEventStream(output) {
            return jsonResult
        }
        return parseConsoleOutput(output)
    }

    // MARK: - Console Output Parsing

    private func parseConsoleOutput(_ output: String) -> TestRunOutput {
        var moduleTests: [String: [TestCaseResult]] = [:]
        var unhandledErrors: [String] = []

        // XCTest: errors come BEFORE the result line — collect until we see the result.
        var pendingErrors: [String] = []

        // Swift Testing: errors come AFTER the result line — track the last failed test
        // so we can attach errors to it when we see them.
        var lastFailedModule: String? = nil
        var lastFailedIndex: Int? = nil

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // XCTest: Test Case '-[Module.Class method]' passed/failed
            if let (moduleName, testResult) = parseXCTestLine(trimmed) {
                let errors = testResult.state == "failed" ? pendingErrors : []
                moduleTests[moduleName, default: []].append(
                    TestCaseResult(
                        name: testResult.name,
                        fullName: testResult.fullName,
                        state: testResult.state,
                        errors: errors.isEmpty ? nil : errors
                    )
                )
                // Reset XCTest pending errors
                pendingErrors.removeAll()
                // Reset Swift Testing tracking (we're in XCTest territory)
                lastFailedModule = nil
                lastFailedIndex = nil
                continue
            }

            // Swift Testing: ✔/✘ Test "name" passed/failed
            if let (suiteName, testResult) = parseSwiftTestingResult(trimmed) {
                let index = moduleTests[suiteName, default: []].count
                moduleTests[suiteName, default: []].append(
                    TestCaseResult(
                        name: testResult.name,
                        fullName: testResult.fullName,
                        state: testResult.state,
                        errors: nil  // errors come after this line, will be attached below
                    )
                )
                if testResult.state == "failed" {
                    lastFailedModule = suiteName
                    lastFailedIndex = index
                } else {
                    lastFailedModule = nil
                    lastFailedIndex = nil
                }
                continue
            }

            // Swift Testing error details come AFTER the ✘ result line.
            // Attach them to the last failed Swift Testing test.
            if isSwiftTestingErrorLine(trimmed) {
                if let mod = lastFailedModule, let idx = lastFailedIndex {
                    let old = moduleTests[mod]![idx]
                    var errors = old.errors ?? []
                    errors.append(trimmed)
                    moduleTests[mod]![idx] = TestCaseResult(
                        name: old.name,
                        fullName: old.fullName,
                        state: old.state,
                        errors: errors
                    )
                }
                continue
            }

            // XCTest failure details come BEFORE the "failed" result line.
            if isXCTestErrorLine(trimmed) {
                pendingErrors.append(trimmed)
                continue
            }

            // Compilation errors (no test was running)
            if isCompilationError(trimmed) {
                unhandledErrors.append(trimmed)
            }
        }

        let modules = moduleTests.map { name, tests in
            TestModuleResult(moduleId: name, tests: tests)
        }

        return TestRunOutput(
            testModules: modules,
            unhandledErrors: unhandledErrors.isEmpty ? nil : unhandledErrors,
            reason: nil
        )
    }

    // MARK: - Line Classification

    /// XCTest format: Test Case '-[Module.Class method]' passed (0.001 seconds).
    private func parseXCTestLine(_ line: String) -> (String, TestCaseResult)? {
        // Module prefix is optional — some configurations omit it.
        // Patterns:
        //   '-[Module.Class method]'
        //   '-[Class method]'  (no module)
        let withModule = #"Test Case '-\[(\S+)\.(\S+)\s+(\w+)\]' (passed|failed)"#
        let withoutModule = #"Test Case '-\[(\S+)\s+(\w+)\]' (passed|failed)"#

        if let match = firstMatch(pattern: withModule, in: line) {
            let module = group(match, 1, in: line) ?? "Unknown"
            let className = group(match, 2, in: line) ?? "Unknown"
            let method = group(match, 3, in: line) ?? "unknown"
            let state = group(match, 4, in: line) ?? "failed"
            return (
                "\(module).\(className)",
                TestCaseResult(name: method, fullName: "-[\(className) \(method)]", state: state, errors: nil)
            )
        }

        if let match = firstMatch(pattern: withoutModule, in: line) {
            let className = group(match, 1, in: line) ?? "Unknown"
            let method = group(match, 2, in: line) ?? "unknown"
            let state = group(match, 3, in: line) ?? "failed"
            return (
                className,
                TestCaseResult(name: method, fullName: "-[\(className) \(method)]", state: state, errors: nil)
            )
        }

        return nil
    }

    /// Swift Testing format: ✔ Test "name" passed after X seconds.
    ///                        ✘ Test "name" failed after X seconds with N issues.
    /// Skips Suite-level lines and "started" lines (no outcome yet).
    private func parseSwiftTestingResult(_ line: String) -> (String, TestCaseResult)? {
        // Only match result lines (✔ or ✘), not started (◇) or detail (↳)
        guard line.hasPrefix("✔") || line.hasPrefix("✘") else { return nil }
        // Skip Suite-level summary lines
        guard !line.contains(" Suite ") else { return nil }
        guard line.contains(" Test ") else { return nil }

        let pattern = #"[✔✘] Test "(.+?)" (passed|failed|skipped)"#
        guard let match = firstMatch(pattern: pattern, in: line) else { return nil }

        let rawName = group(match, 1, in: line) ?? "unknown"
        let state = group(match, 2, in: line) ?? "failed"

        // rawName may be "SuiteName/testName()" or just "testName()"
        let components = rawName.components(separatedBy: "/")
        let suiteName: String
        let testName: String
        if components.count > 1 {
            suiteName = components.dropLast().joined(separator: "/")
            testName = components.last ?? rawName
        } else {
            suiteName = "SwiftTesting"
            testName = rawName
        }

        return (
            suiteName,
            TestCaseResult(name: testName, fullName: rawName, state: state, errors: nil)
        )
    }

    /// Swift Testing error detail lines start with ↳ or contain "Issue recorded".
    /// E.g.: `↳ CalculatorTests/add():10: Expectation failed: (result → 0) == (5)`
    private func isSwiftTestingErrorLine(_ line: String) -> Bool {
        if line.hasPrefix("↳") { return true }
        if line.contains("Issue recorded") { return true }
        if line.contains("Expectation failed") { return true }
        return false
    }

    /// XCTest failure detail lines contain assertion keywords.
    /// E.g.: `/path/file.swift:10: error: -[Class method] : XCTAssertEqual failed`
    private func isXCTestErrorLine(_ line: String) -> Bool {
        guard line.contains("XCTAssert") || line.contains("XCTFail") else { return false }
        return line.contains("failed") || line.contains("error:")
    }

    /// Compilation / linker errors that happen before any test runs.
    private func isCompilationError(_ line: String) -> Bool {
        guard line.contains("error:") else { return false }
        // Exclude XCTest result lines that contain "error:" in the method name path
        if line.contains("Test Case") { return false }
        // Exclude Swift Testing result lines
        if line.hasPrefix("✔") || line.hasPrefix("✘") { return false }
        return true
    }

    // MARK: - Regex Helpers

    private func firstMatch(pattern: String, in string: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string))
    }

    private func group(_ match: NSTextCheckingResult, _ index: Int, in string: String) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: string) else { return nil }
        return String(string[range])
    }

    // MARK: - JSON Event Stream Parsing

    /// Parses `swift test --experimental-event-stream-output` JSON lines.
    private func parseEventStream(_ output: String) -> TestRunOutput? {
        let lines = output.components(separatedBy: .newlines).filter { $0.hasPrefix("{") }
        guard !lines.isEmpty else { return nil }

        // Verify it's actually an event stream (has a "kind" key at the top level)
        guard let firstData = lines.first?.data(using: .utf8),
              let firstJson = try? JSONSerialization.jsonObject(with: firstData) as? [String: Any],
              firstJson["kind"] != nil else {
            return nil
        }

        var moduleTests: [String: [TestCaseResult]] = [:]
        let unhandledErrors: [String] = []

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let kind = json["kind"] as? String,
                  kind == "event",
                  let payload = json["payload"] as? [String: Any],
                  let payloadKind = payload["kind"] as? String else { continue }

            guard payloadKind == "testEnded" || payloadKind == "testCaseEnded" else { continue }

            guard let testInfo = payload["test"] as? [String: Any]
                    ?? payload["testCase"] as? [String: Any],
                  let name = testInfo["name"] as? String else { continue }

            let statusStr = (payload["result"] as? String) ?? "failed"
            let state: String
            switch statusStr {
            case "passed": state = "passed"
            case "failed": state = "failed"
            case "skipped": state = "skipped"
            default: state = "failed"
            }

            let issues = (payload["issues"] as? [[String: Any]])?.compactMap {
                $0["message"] as? String
            }

            // Derive module name from source file path if available
            let sourceFile = (testInfo["sourceLocation"] as? [String: Any])?["_filePath"] as? String ?? ""
            let moduleName = URL(fileURLWithPath: sourceFile)
                .deletingPathExtension()
                .lastPathComponent
                .isEmpty ? "SwiftTesting" : URL(fileURLWithPath: sourceFile).deletingPathExtension().lastPathComponent

            moduleTests[moduleName, default: []].append(
                TestCaseResult(
                    name: name,
                    fullName: name,
                    state: state,
                    errors: issues?.isEmpty == false ? issues : nil
                )
            )
        }

        guard !moduleTests.isEmpty || !unhandledErrors.isEmpty else { return nil }

        return TestRunOutput(
            testModules: moduleTests.map { TestModuleResult(moduleId: $0.key, tests: $0.value) },
            unhandledErrors: unhandledErrors.isEmpty ? nil : unhandledErrors,
            reason: nil
        )
    }
}
