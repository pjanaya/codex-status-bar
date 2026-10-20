import Foundation

public struct AppServerUsageReader: Sendable {
    public enum ReaderError: Error {
        case codexNotFound
        case invalidResponse
        case requestFailed
    }

    private let codexPath: String?

    public init(fileManager: FileManager = .default) {
        self.init(
            fileManager: fileManager,
            codexPaths: Self.defaultCodexPaths(
                homeDirectory: fileManager.homeDirectoryForCurrentUser
            )
        )
    }

    public init(fileManager: FileManager = .default, codexPaths: [String]) {
        codexPath = codexPaths.first(where: fileManager.isExecutableFile)
    }

    static func defaultCodexPaths(homeDirectory: URL) -> [String] {
        [
            "/Applications/ChatGPT.app/Contents/Resources/" +
                "codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/" +
                "codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(homeDirectory.path)/Applications/ChatGPT.app/Contents/Resources/" +
                "codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "\(homeDirectory.path)/Applications/Codex.app/Contents/Resources/" +
                "codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "\(homeDirectory.path)/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(homeDirectory.path)/Applications/Codex.app/Contents/Resources/codex"
        ]
    }

    public func latestSnapshot() async throws -> UsageSnapshot {
        guard let codexPath else {
            throw ReaderError.codexNotFound
        }

        return try await withThrowingTaskGroup(of: UsageSnapshot.self) { group in
            group.addTask {
                try requestSnapshot(codexPath: codexPath)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(8))
                throw ReaderError.requestFailed
            }

            guard let snapshot = try await group.next() else {
                throw ReaderError.requestFailed
            }

            group.cancelAll()
            return snapshot
        }
    }

    public func snapshot(from responseData: Data, observedAt: Date = Date()) -> UsageSnapshot? {
        let lines = responseData.split(separator: 0x0A, omittingEmptySubsequences: true)

        for line in lines {
            guard let response = try? JSONDecoder().decode(Response.self, from: Data(line)) else {
                continue
            }

            guard response.id == 2, let rateLimits = response.result?.rateLimits else {
                continue
            }

            let windows = [rateLimits.primary?.usageWindow, rateLimits.secondary?.usageWindow]
                .compactMap { $0 }
            guard !windows.isEmpty else {
                continue
            }

            return UsageSnapshot(
                fiveHour: windows.firstFiveHourWindow,
                weekly: windows.firstWeeklyWindow,
                observedAt: observedAt
            )
        }

        return nil
    }

    private func requestSnapshot(codexPath: String) throws -> UsageSnapshot {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        try process.run()

        let initializeRequest = """
        {"id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-status-bar","title":"Codex Status Bar","version":"0.1.0"},"capabilities":{"experimentalApi":true}}}

        """
        let rateLimitsRequest = """
        {"method":"initialized"}
        {"id":2,"method":"account/rateLimits/read"}

        """

        inputPipe.fileHandleForWriting.write(Data(initializeRequest.utf8))
        Thread.sleep(forTimeInterval: 0.2)
        inputPipe.fileHandleForWriting.write(Data(rateLimitsRequest.utf8))
        Thread.sleep(forTimeInterval: 2)
        try inputPipe.fileHandleForWriting.close()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ReaderError.requestFailed
        }

        guard let snapshot = snapshot(from: data) else {
            throw ReaderError.invalidResponse
        }

        return snapshot
    }
}

private struct Response: Decodable {
    let id: Int?
    let result: Result?
}

private struct Result: Decodable {
    let rateLimits: RateLimits
}

private struct RateLimits: Decodable {
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
}

private struct RateLimitWindow: Decodable {
    let usedPercent: Int
    let resetsAt: Int?
    let windowDurationMins: Int?

    var usageWindow: UsageWindow? {
        guard let resetsAt else {
            return nil
        }

        return UsageWindow(
            usedPercent: usedPercent,
            resetDate: Date(timeIntervalSince1970: TimeInterval(resetsAt)),
            windowMinutes: windowDurationMins
        )
    }
}

private extension Array where Element == UsageWindow {
    var firstFiveHourWindow: UsageWindow? {
        first { $0.windowMinutes == 300 }
    }

    var firstWeeklyWindow: UsageWindow? {
        first { $0.windowMinutes == 10_080 } ?? first
    }
}
