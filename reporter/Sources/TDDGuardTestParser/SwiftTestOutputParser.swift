import Foundation

/// Parses `swift test` console output into the tdd-guard JSON schema.
///
/// Works with both XCTest and Swift Testing output formats:
///
/// XCTest output:
///   Test Case '-[ModuleTests.CalculatorTests testAdd]' started.
///   Test Case '-[ModuleTests.CalculatorTests testAdd]' passed (0.001 seconds).
///   Test Case '-[ModuleTests.CalculatorTests testFail]' failed (0.002 seconds).
///
/// Swift Testing output:
///   ◇ Test "add returns sum" started.
///   ✔ Test "add returns sum" passed after 0.001 seconds.
///   ✘ Test "subtract returns difference" failed after 0.002 seconds.
///   ▷ Suite "CalculatorTests" started.
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
        // Try JSON event stream first (from --experimental-event-stream-output)
        if let jsonResult = parseEventStream(output) {
            return jsonResult
        }

        // Fall back to console output parsing
        return parseConsoleOutput(output)
    }

    // MARK: - Console Output Parsing

    private func parseConsoleOutput(_ output: String) -> TestRunOutput {
        var moduleTests: [String: [TestCaseResult]] = [:]
        var unhandledErrors: [String] = []
        var pendingErrors: [String] = []

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // XCTest: Test Case '-[Module.Class testMethod]' passed/failed
            if let result = parseXCTestLine(line) {
                let (moduleName, testResult) = result
                var errors = testResult.errors ?? []
                if testResult.state == "failed" {
                    errors.append(contentsOf: pendingErrors)
                }
                let finalResult = TestCaseResult(
                    name: testResult.name,
                    fullName: testResult.fullName,
                    state: testResult.state,
                    errors: errors.isEmpty ? nil : errors
                )
                moduleTests[moduleName, default: []].append(finalResult)
                pendingErrors.removeAll()
                continue
            }

            // Swift Testing: ✔ Test "name" passed / ✘ Test "name" failed
            if let result = parseSwiftTestingLine(line) {
                let (suiteName, testResult) = result
                var errors = testResult.errors ?? []
                if testResult.state == "failed" {
                    errors.append(contentsOf: pendingErrors)
                }
                let finalResult = TestCaseResult(
                    name: testResult.name,
                    fullName: testResult.fullName,
                    state: testResult.state,
                    errors: errors.isEmpty ? nil : errors
                )
                moduleTests[suiteName, default: []].append(finalResult)
                pendingErrors.removeAll()
                continue
            }

            // Collect error/failure detail lines
            if line.contains("XCTAssert") || line.contains("failed:") ||
               line.contains("Expectation failed") || line.contains("#expect") ||
               line.contains("#require") || line.contains("Issue recorded") {
                pendingErrors.append(line.trimmingCharacters(in: .whitespaces))
                continue
            }

            // Compilation errors
            if line.contains("error:") && !line.contains("Test Case") {
                unhandledErrors.append(line.trimmingCharacters(in: .whitespaces))
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

    /// Parses XCTest-style output line.
    /// Format: `Test Case '-[Module.Class testMethod]' passed (0.001 seconds).`
    private func parseXCTestLine(_ line: String) -> (String, TestCaseResult)? {
        // Match: Test Case '-[Module.ClassName testMethodName]' passed/failed
        let pattern = #"Test Case '-\[(\S+)\.(\S+)\s+(\S+)\]' (passed|failed)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
              ) else {
            return nil
        }

        let moduleName = extractGroup(match, at: 1, in: line) ?? "Unknown"
        let className = extractGroup(match, at: 2, in: line) ?? "Unknown"
        let methodName = extractGroup(match, at: 3, in: line) ?? "unknown"
        let stateStr = extractGroup(match, at: 4, in: line) ?? "failed"

        let fullName = "-[\(className) \(methodName)]"
        let result = TestCaseResult(
            name: methodName,
            fullName: fullName,
            state: stateStr,
            errors: nil
        )

        return ("\(moduleName).\(className)", result)
    }

    /// Parses Swift Testing-style output line.
    /// Format: `✔ Test "name" passed after 0.001 seconds.`
    /// Format: `✘ Test "name" failed after 0.002 seconds.`
    private func parseSwiftTestingLine(_ line: String) -> (String, TestCaseResult)? {
        // Match passed: ✔ Test "name" passed
        // Match failed: ✘ Test "name" failed
        // Match skipped: ↳ Test "name" skipped
        let pattern = #"[✔✘↳◇▷] (?:Test|Suite) \"(.+?)\".*?(passed|failed|skipped)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
              ) else {
            return nil
        }

        let testName = extractGroup(match, at: 1, in: line) ?? "unknown"
        let stateStr = extractGroup(match, at: 2, in: line) ?? "failed"

        // For Swift Testing, suite name may be embedded in a path like "SuiteName/testName"
        let components = testName.components(separatedBy: "/")
        let name: String
        let suiteName: String
        if components.count > 1 {
            suiteName = components.dropLast().joined(separator: "/")
            name = components.last ?? testName
        } else {
            suiteName = "SwiftTesting"
            name = testName
        }

        // Skip suite-level entries (they don't represent individual tests)
        if line.contains("Suite") {
            return nil
        }

        let result = TestCaseResult(
            name: name,
            fullName: testName,
            state: stateStr,
            errors: nil
        )

        return (suiteName, result)
    }

    private func extractGroup(
        _ match: NSTextCheckingResult,
        at index: Int,
        in string: String
    ) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: string) else {
            return nil
        }
        return String(string[range])
    }

    // MARK: - JSON Event Stream Parsing

    /// Parses `swift test --experimental-event-stream-output` JSON events.
    /// Each line is a separate JSON object.
    private func parseEventStream(_ output: String) -> TestRunOutput? {
        let lines = output.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("{") }

        guard !lines.isEmpty else { return nil }

        // Check if this looks like event stream output
        guard let firstData = lines.first?.data(using: .utf8),
              let firstJson = try? JSONSerialization.jsonObject(with: firstData) as? [String: Any],
              firstJson["kind"] != nil else {
            return nil
        }

        var moduleTests: [String: [TestCaseResult]] = [:]
        var unhandledErrors: [String] = []

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            guard let kind = json["kind"] as? String else { continue }

            if kind == "event" {
                parseStreamEvent(json, into: &moduleTests, errors: &unhandledErrors)
            }
        }

        // If we found no test results from events, this wasn't a valid event stream
        guard !moduleTests.isEmpty || !unhandledErrors.isEmpty else { return nil }

        let modules = moduleTests.map { name, tests in
            TestModuleResult(moduleId: name, tests: tests)
        }

        return TestRunOutput(
            testModules: modules,
            unhandledErrors: unhandledErrors.isEmpty ? nil : unhandledErrors,
            reason: nil
        )
    }

    private func parseStreamEvent(
        _ json: [String: Any],
        into moduleTests: inout [String: [TestCaseResult]],
        errors: inout [String]
    ) {
        guard let payload = json["payload"] as? [String: Any],
              let kind = payload["kind"] as? String else { return }

        // We care about testEnded events
        guard kind == "testEnded" || kind == "testCaseEnded" else { return }

        guard let testPayload = payload["test"] as? [String: Any] ?? payload["testCase"] as? [String: Any],
              let name = testPayload["name"] as? String else { return }

        let suiteName = (testPayload["sourceLocation"] as? [String: Any])?["_filePath"] as? String
            ?? (testPayload["tags"] as? [[String: Any]])?.first?["name"] as? String
            ?? "SwiftTesting"

        let status = (payload["result"] as? String) ?? "unknown"
        let state: String
        switch status {
        case "passed": state = "passed"
        case "failed": state = "failed"
        case "skipped": state = "skipped"
        default: state = "failed"
        }

        let issueMessages: [String]? = (payload["issues"] as? [[String: Any]])?.compactMap {
            $0["message"] as? String
        }

        let result = TestCaseResult(
            name: name,
            fullName: name,
            state: state,
            errors: issueMessages?.isEmpty == false ? issueMessages : nil
        )

        // Use the file path's last component as the module name
        let moduleName: String
        if let filePath = suiteName.components(separatedBy: "/").last {
            moduleName = filePath.replacingOccurrences(of: ".swift", with: "")
        } else {
            moduleName = suiteName
        }

        moduleTests[moduleName, default: []].append(result)
    }
}
