import Foundation

public enum FiveHourLimitDisplayMode: String, CaseIterable, Sendable {
    case show
    case hide
    case dynamic

    public func shouldShow(hasLimit: Bool) -> Bool {
        switch self {
        case .show:
            return true
        case .hide:
            return false
        case .dynamic:
            return hasLimit
        }
    }
}

public struct UsageWindow: Equatable, Sendable {
    public let usedPercent: Int
    public let resetDate: Date
    public let windowMinutes: Int?

    public init(usedPercent: Int, resetDate: Date, windowMinutes: Int? = nil) {
        self.usedPercent = usedPercent
        self.resetDate = resetDate
        self.windowMinutes = windowMinutes
    }

    public func remainingPercent(at date: Date) -> Int {
        if date >= resetDate {
            return 100
        }

        return max(0, min(100, 100 - usedPercent))
    }
}

public struct UsageSnapshot: Equatable, Sendable {
    public let fiveHour: UsageWindow?
    public let weekly: UsageWindow?
    public let observedAt: Date

    public init(fiveHour: UsageWindow?, weekly: UsageWindow?, observedAt: Date) {
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.observedAt = observedAt
    }
}
