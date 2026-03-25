import Foundation

/// A single test case result.
struct TestCaseResult: Codable {
    let name: String
    let fullName: String
    let state: String
    let errors: [String]?
}

/// A test module containing multiple test cases.
struct TestModuleResult: Codable {
    let moduleId: String
    let tests: [TestCaseResult]
}

/// The complete test run output, compatible with tdd-guard's expected schema.
struct TestRunOutput: Codable {
    let testModules: [TestModuleResult]
    let unhandledErrors: [String]?
    let reason: String?
}
