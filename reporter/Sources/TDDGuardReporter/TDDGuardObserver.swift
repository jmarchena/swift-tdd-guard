import Foundation
import XCTest

/// XCTest observer that writes test results to a JSON file
/// for consumption by swift-tdd-guard hooks.
///
/// Usage: Add to your test target's principal class or register manually:
///
/// ```swift
/// // In a test file or setup:
/// XCTestObservationCenter.shared.addTestObserver(TDDGuardObserver())
/// ```
///
/// Or create a principal class that registers it automatically:
///
/// ```swift
/// // LinkerDirective.swift (in test target)
/// import XCTest
/// import TDDGuardReporter
///
/// class TestObserverRegistration: NSObject {
///     override init() {
///         super.init()
///         XCTestObservationCenter.shared.addTestObserver(TDDGuardObserver())
///     }
/// }
/// ```
public final class TDDGuardObserver: NSObject, XCTestObservation {
    private var results: [String: [TestCaseResult]] = [:]
    private var unhandledErrors: [String] = []
    private let outputPath: String

    /// Creates a new observer.
    /// - Parameter outputPath: Path to write test results JSON. Defaults to
    ///   `.claude/tdd-guard/data/test.json` relative to the current directory.
    public init(outputPath: String? = nil) {
        self.outputPath = outputPath
            ?? ProcessInfo.processInfo.environment["TDD_GUARD_TEST_OUTPUT"]
            ?? ".claude/tdd-guard/data/test.json"
        super.init()
    }

    public func testBundleWillStart(_ testBundle: Bundle) {
        results.removeAll()
        unhandledErrors.removeAll()
    }

    public func testCaseDidFinish(_ testCase: XCTestCase) {
        let className = String(describing: type(of: testCase))
        let testName = testCase.name
        let run = testCase.testRun

        let state: String
        if let run = run {
            if run.hasBeenSkipped {
                state = "skipped"
            } else if run.hasSucceeded {
                state = "passed"
            } else {
                state = "failed"
            }
        } else {
            state = "skipped"
        }

        let errors: [String]? = run.flatMap { r in
            let failures = r.failureCount > 0
            if failures {
                // Collect failure descriptions
                return ["\(testName) failed"]
            }
            return nil
        }

        let result = TestCaseResult(
            name: extractMethodName(from: testName),
            fullName: testName,
            state: state,
            errors: errors
        )

        results[className, default: []].append(result)
    }

    public func testBundleDidFinish(_ testBundle: Bundle) {
        writeResults()
    }

    private func extractMethodName(from testName: String) -> String {
        // XCTest format: "-[ClassName testMethodName]"
        // We want just "testMethodName"
        if let match = testName.range(of: #"\s(\w+)\]"#, options: .regularExpression) {
            let extracted = testName[match].dropFirst().dropLast()
            return String(extracted)
        }
        return testName
    }

    private func writeResults() {
        let modules = results.map { className, tests in
            TestModuleResult(moduleId: className, tests: tests)
        }

        let output = TestRunOutput(
            testModules: modules,
            unhandledErrors: unhandledErrors.isEmpty ? nil : unhandledErrors,
            reason: nil
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(output)

            let url = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url)
        } catch {
            print("[TDDGuardReporter] Failed to write test results: \(error)")
        }
    }
}
