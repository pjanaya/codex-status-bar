import Foundation

public struct UsageWindow: Equatable, Sendable {
    public let usedPercent: Int
    public let resetDate: Date

    public init(usedPercent: Int, resetDate: Date) {
        self.usedPercent = usedPercent
        self.resetDate = resetDate
    }

    public func remainingPercent(at date: Date) -> Int {
        if date >= resetDate {
            return 100
        }

        return max(0, min(100, 100 - usedPercent))
    }
}

public struct UsageSnapshot: Equatable, Sendable {
    public let fiveHour: UsageWindow
    public let weekly: UsageWindow
    public let observedAt: Date

    public init(fiveHour: UsageWindow, weekly: UsageWindow, observedAt: Date) {
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.observedAt = observedAt
    }
}
