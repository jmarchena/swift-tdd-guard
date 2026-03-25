import XCTest
@testable import TDDGuardReporter

final class TestResultTests: XCTestCase {
    func testTestCaseResultEncoding() throws {
        let result = TestCaseResult(
            name: "testAdd",
            fullName: "-[CalculatorTests testAdd]",
            state: "passed",
            errors: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["name"] as? String, "testAdd")
        XCTAssertEqual(json["state"] as? String, "passed")
    }

    func testTestRunOutputEncoding() throws {
        let testCase = TestCaseResult(
            name: "testSubtract",
            fullName: "-[CalculatorTests testSubtract]",
            state: "failed",
            errors: ["Expected 5 but got 3"]
        )
        let module = TestModuleResult(
            moduleId: "CalculatorTests",
            tests: [testCase]
        )
        let output = TestRunOutput(
            testModules: [module],
            unhandledErrors: nil,
            reason: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(output)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let modules = json["testModules"] as! [[String: Any]]
        XCTAssertEqual(modules.count, 1)
        XCTAssertEqual(modules[0]["moduleId"] as? String, "CalculatorTests")
    }
}
