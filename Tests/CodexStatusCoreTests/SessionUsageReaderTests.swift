import CodexStatusCore
import Foundation
import Testing

struct SessionUsageReaderTests {
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
        {"type":"other"}
        {"payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":5.0,"window_minutes":300,"resets_at":2000000000},"secondary":{"used_percent":11.0,"window_minutes":10080,"resets_at":2000600000}}}}

        """
        try contents.write(to: file, atomically: true, encoding: .utf8)

        let snapshot = SessionUsageReader(sessionsDirectory: directory).latestSnapshot()

        #expect(snapshot?.fiveHour.usedPercent == 5)
        #expect(snapshot?.weekly.usedPercent == 11)
        #expect(snapshot?.fiveHour.resetDate.timeIntervalSince1970 == 2_000_000_000)
    }

    @Test
    func returnsFullAllowanceAfterReset() {
        let resetDate = Date(timeIntervalSince1970: 100)
        let window = UsageWindow(usedPercent: 73, resetDate: resetDate)

        #expect(window.remainingPercent(at: Date(timeIntervalSince1970: 99)) == 27)
        #expect(window.remainingPercent(at: resetDate) == 100)
    }
}
