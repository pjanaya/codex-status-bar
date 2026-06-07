import CodexStatusCore
import Foundation

@MainActor
final class UsageMonitor {
    var onChange: ((UsageSnapshot?, Date) -> Void)?

    private let appServerReader = AppServerUsageReader()
    private let reader: SessionUsageReader
    private var pollTimer: Timer?
    private var resetTimer: Timer?
    private var snapshot: UsageSnapshot?

    init() {
        let sessionsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)

        reader = SessionUsageReader(sessionsDirectory: sessionsDirectory)
    }

    func start() {
        refresh()

        pollTimer = Timer.scheduledTimer(
            withTimeInterval: 5 * 60,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        Task {
            do {
                snapshot = try await appServerReader.latestSnapshot()
            } catch {
                snapshot = reader.latestSnapshot()
            }

            publish()
            scheduleNextReset()
        }
    }

    private func publish() {
        onChange?(snapshot, Date())
    }

    private func scheduleNextReset() {
        resetTimer?.invalidate()

        guard let snapshot else {
            return
        }

        let now = Date()
        let futureResets = [
            snapshot.fiveHour.resetDate,
            snapshot.weekly.resetDate
        ].filter { $0 > now }

        guard let nextReset = futureResets.min() else {
            return
        }

        resetTimer = Timer(fire: nextReset, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.publish()
                self?.scheduleNextReset()
            }
        }

        if let resetTimer {
            RunLoop.main.add(resetTimer, forMode: .common)
        }
    }
}
