import Foundation

/// CLI tool that wraps `swift test` and writes results to the tdd-guard JSON format.
///
/// Usage:
///   tdd-guard-swift-test                    # runs `swift test`, streams output, writes test.json
///   tdd-guard-swift-test --filter MyTest    # forwards extra args to `swift test`
///   swift test 2>&1 | tdd-guard-swift-test --stdin   # parse piped output

let outputPath = ProcessInfo.processInfo.environment["TDD_GUARD_TEST_OUTPUT"]
    ?? ".claude/tdd-guard/data/test.json"

let args = CommandLine.arguments

if args.contains("--stdin") {
    var input = ""
    while let line = readLine(strippingNewline: false) {
        input += line
    }
    let parser = SwiftTestOutputParser()
    writeResult(parser.parse(input), to: outputPath)
} else {
    let extraArgs = args.dropFirst().filter { $0 != "--stdin" }
    let exitCode = runSwiftTest(extraArgs: Array(extraArgs), outputPath: outputPath)
    exit(exitCode)
}

// MARK: - Run swift test

func runSwiftTest(extraArgs: [String], outputPath: String) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "test"] + extraArgs

    // Pipes to capture output while also streaming it to the terminal
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    var capturedStdout = Data()
    var capturedStderr = Data()

    // Read both pipes concurrently to avoid deadlock.
    // If we call readDataToEndOfFile() sequentially after waitUntilExit(),
    // the process can block waiting for its pipe to be drained while we wait
    // for the process to finish — a classic deadlock.
    let group = DispatchGroup()

    group.enter()
    DispatchQueue.global().async {
        defer { group.leave() }
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        // Stream to terminal in real-time
        FileHandle.standardOutput.write(data)
        capturedStdout = data
    }

    group.enter()
    DispatchQueue.global().async {
        defer { group.leave() }
        let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        FileHandle.standardError.write(data)
        capturedStderr = data
    }

    do {
        try process.run()
    } catch {
        fputs("swift-tdd-guard: failed to launch swift test: \(error)\n", stderr)
        return 1
    }

    process.waitUntilExit()
    group.wait()

    let stdout = String(data: capturedStdout, encoding: .utf8) ?? ""
    let stderr = String(data: capturedStderr, encoding: .utf8) ?? ""
    let combined = stdout + "\n" + stderr

    let parser = SwiftTestOutputParser()
    writeResult(parser.parse(combined), to: outputPath)

    return process.terminationStatus
}

// MARK: - Write JSON

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
        fputs("swift-tdd-guard: failed to write test results: \(error)\n", stderr)
    }
}
