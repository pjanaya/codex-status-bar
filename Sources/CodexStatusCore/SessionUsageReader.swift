import Foundation

public struct SessionUsageReader {
    private let sessionsDirectory: URL
    private let fileManager: FileManager
    private let maximumTailSize = 512 * 1024

    public init(
        sessionsDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.sessionsDirectory = sessionsDirectory
        self.fileManager = fileManager
    }

    public func latestSnapshot() -> UsageSnapshot? {
        let files = recentSessionFiles()
        var latestSnapshot: UsageSnapshot?

        for file in files {
            guard let snapshot = snapshot(from: file.url) else {
                continue
            }

            if snapshot.observedAt > (latestSnapshot?.observedAt ?? .distantPast) {
                latestSnapshot = snapshot
            }
        }

        return latestSnapshot
    }

    private func recentSessionFiles() -> [(url: URL, modifiedAt: Date)] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [(url: URL, modifiedAt: Date)] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else {
                continue
            }

            guard let values = try? fileURL.resourceValues(forKeys: keys) else {
                continue
            }

            guard values.isRegularFile == true, let modifiedAt = values.contentModificationDate else {
                continue
            }

            files.append((fileURL, modifiedAt))
        }

        return files.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func snapshot(from fileURL: URL) -> UsageSnapshot? {
        guard let data = readTail(of: fileURL) else {
            return nil
        }

        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)

        for line in lines.reversed() {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) else {
                continue
            }

            guard let dictionary = object as? [String: Any] else {
                continue
            }

            guard let rateLimits = findDictionary(named: "rate_limits", in: dictionary) else {
                continue
            }

            guard let observedAt = eventDate(from: dictionary) else {
                continue
            }

            if let snapshot = makeSnapshot(from: rateLimits, observedAt: observedAt) {
                return snapshot
            }
        }

        return nil
    }

    private func eventDate(from dictionary: [String: Any]) -> Date? {
        guard let timestamp = dictionary["timestamp"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp)
    }

    private func readTail(of fileURL: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }

        defer {
            try? handle.close()
        }

        guard let fileSize = try? handle.seekToEnd() else {
            return nil
        }

        let bytesToRead = min(UInt64(maximumTailSize), fileSize)
        let offset = fileSize - bytesToRead

        do {
            try handle.seek(toOffset: offset)
            var data = try handle.readToEnd() ?? Data()

            if offset > 0, let firstNewline = data.firstIndex(of: 0x0A) {
                data.removeSubrange(data.startIndex...firstNewline)
            }

            return data
        } catch {
            return nil
        }
    }

    private func findDictionary(named key: String, in value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            if let match = dictionary[key] as? [String: Any] {
                return match
            }

            for child in dictionary.values {
                if let match = findDictionary(named: key, in: child) {
                    return match
                }
            }
        }

        if let array = value as? [Any] {
            for child in array {
                if let match = findDictionary(named: key, in: child) {
                    return match
                }
            }
        }

        return nil
    }

    private func makeSnapshot(
        from rateLimits: [String: Any],
        observedAt: Date
    ) -> UsageSnapshot? {
        let windows = [
            makeWindow(from: rateLimits["primary"]),
            makeWindow(from: rateLimits["secondary"])
        ].compactMap { $0 }
        guard !windows.isEmpty else {
            return nil
        }

        return UsageSnapshot(
            fiveHour: windows.firstFiveHourWindow,
            weekly: windows.firstWeeklyWindow,
            observedAt: observedAt
        )
    }

    private func makeWindow(from value: Any?) -> UsageWindow? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }

        guard let usedPercent = number(from: dictionary["used_percent"]) else {
            return nil
        }

        guard let resetTimestamp = number(from: dictionary["resets_at"]) else {
            return nil
        }

        let windowMinutes = number(from: dictionary["window_minutes"]).map(Int.init)

        return UsageWindow(
            usedPercent: Int(usedPercent.rounded()),
            resetDate: Date(timeIntervalSince1970: resetTimestamp),
            windowMinutes: windowMinutes
        )
    }

    private func number(from value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let string = value as? String {
            return Double(string)
        }

        return nil
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
