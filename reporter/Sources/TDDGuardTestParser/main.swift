import Foundation

/// CLI tool that wraps `swift test` and writes results to the tdd-guard JSON format.
///
/// Usage:
///   tdd-guard-swift-test                    # runs `swift test` and parses output
///   echo "test output" | tdd-guard-swift-test --stdin   # parse piped output
///
/// Works with both XCTest and Swift Testing output.

let outputPath = ProcessInfo.processInfo.environment["TDD_GUARD_TEST_OUTPUT"]
    ?? ".claude/tdd-guard/data/test.json"

let args = CommandLine.arguments

if args.contains("--stdin") {
    // Parse from stdin
    var input = ""
    while let line = readLine(strippingNewline: false) {
        input += line
    }
    let parser = SwiftTestOutputParser()
    let result = parser.parse(input)
    writeResult(result, to: outputPath)
} else {
    // Run `swift test` and capture output
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "test"] + Array(args.dropFirst())

    let pipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = pipe
    process.standardError = errorPipe

    do {
        try process.run()
    } catch {
        fputs("Error: Failed to run swift test: \(error)\n", stderr)
        exit(1)
    }

    // Stream output to terminal while capturing it
    let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

    process.waitUntilExit()

    let output = String(data: outputData, encoding: .utf8) ?? ""
    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

    // Print to terminal so the user sees test output
    if !output.isEmpty { print(output, terminator: "") }
    if !errorOutput.isEmpty { fputs(errorOutput, stderr) }

    // Parse and write results
    let combined = output + "\n" + errorOutput
    let parser = SwiftTestOutputParser()
    let result = parser.parse(combined)
    writeResult(result, to: outputPath)

    // Exit with the same code as swift test
    exit(process.terminationStatus)
}

func writeResult(_ result: SwiftTestOutputParser.TestRunOutput, to path: String) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    do {
        let data = try encoder.encode(result)
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    } catch {
        fputs("[tdd-guard-swift-test] Failed to write results: \(error)\n", stderr)
    }
}
