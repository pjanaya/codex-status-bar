import CodexStatusCore
import Foundation
import Testing

struct SessionUsageReaderTests {
    @Test
    func readsAppServerRateLimitResponse() {
        let response = """
        {"id":1,"result":{"userAgent":"Codex"}}
        {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":100,"windowDurationMins":300,"resetsAt":2000000000},"secondary":{"usedPercent":61,"windowDurationMins":10080,"resetsAt":2000600000}}}}
        """

        let snapshot = AppServerUsageReader().snapshot(from: Data(response.utf8))

        #expect(snapshot?.fiveHour.usedPercent == 100)
        #expect(snapshot?.weekly.usedPercent == 61)
    }

    @Test
    func readsLatestRateLimitSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("rollout.jsonl")
        let contents = """
        {"timestamp":"2026-06-06T20:00:00.000Z","type":"other"}
        {"timestamp":"2026-06-06T20:01:00.000Z","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":5.0,"window_minutes":300,"resets_at":2000000000},"secondary":{"used_percent":11.0,"window_minutes":10080,"resets_at":2000600000}}}}

        """
        try contents.write(to: file, atomically: true, encoding: .utf8)

        let snapshot = SessionUsageReader(sessionsDirectory: directory).latestSnapshot()

        #expect(snapshot?.fiveHour.usedPercent == 5)
        #expect(snapshot?.weekly.usedPercent == 11)
        #expect(snapshot?.fiveHour.resetDate.timeIntervalSince1970 == 2_000_000_000)
    }

    @Test
    func choosesNewestEventAcrossConcurrentSessionFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let newerEvent = directory.appendingPathComponent("newer-event.jsonl")
        try jsonLine(timestamp: "2026-06-06T22:30:00.000Z", usedPercent: 64)
            .write(to: newerEvent, atomically: true, encoding: .utf8)

        let olderEvent = directory.appendingPathComponent("older-event.jsonl")
        try jsonLine(timestamp: "2026-06-06T22:20:00.000Z", usedPercent: 53)
            .write(to: olderEvent, atomically: true, encoding: .utf8)

        try FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: olderEvent.path
        )

        let snapshot = SessionUsageReader(sessionsDirectory: directory).latestSnapshot()

        #expect(snapshot?.fiveHour.usedPercent == 64)
    }

    @Test
    func returnsFullAllowanceAfterReset() {
        let resetDate = Date(timeIntervalSince1970: 100)
        let window = UsageWindow(usedPercent: 73, resetDate: resetDate)

        #expect(window.remainingPercent(at: Date(timeIntervalSince1970: 99)) == 27)
        #expect(window.remainingPercent(at: resetDate) == 100)
    }

    private func jsonLine(timestamp: String, usedPercent: Int) -> String {
        """
        {"timestamp":"\(timestamp)","payload":{"rate_limits":{"primary":{"used_percent":\(usedPercent),"resets_at":2000000000},"secondary":{"used_percent":10,"resets_at":2000600000}}}}
        """
    }
}
