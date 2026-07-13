import AppKit
import CodexStatusCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = UsageMonitor()
    private let statusItem = NSStatusBar.system.statusItem(withLength: 59)
    private let statusLabel = NSTextField(labelWithString: "")
    private var refreshMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()

        monitor.onChange = { [weak self] snapshot, now in
            self?.updateTitle(snapshot: snapshot, now: now)
        }

        monitor.start()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.toolTip = "Codex allowance remaining"
        button.title = ""

        statusLabel.alignment = .center
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byClipping
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: 1.5)
        ])

        let menu = NSMenu()
        let refreshMenuItem = menu.addItem(
            withTitle: "Refresh",
            action: #selector(refresh),
            keyEquivalent: "r"
        )
        self.refreshMenuItem = refreshMenuItem
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Codex Status Bar",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    private func updateTitle(snapshot: UsageSnapshot?, now: Date) {
        guard let snapshot else {
            setTitle(
                firstPercent: nil,
                firstReset: "--:--",
                secondPercent: nil,
                secondReset: "--/--"
            )
            return
        }

        let fiveHourRemaining = snapshot.fiveHour?.remainingPercent(at: now)
        let weeklyRemaining = snapshot.weekly?.remainingPercent(at: now)

        setTitle(
            firstPercent: fiveHourRemaining,
            firstReset: snapshot.fiveHour?.resetDate.formattedResetTime ?? "--:--",
            secondPercent: weeklyRemaining,
            secondReset: snapshot.weekly?.resetDate.formattedResetDay ?? "--/--"
        )

        statusItem.button?.toolTip = [
            "Codex allowance remaining",
            "Updated \(snapshot.observedAt.formatted(date: .abbreviated, time: .shortened))"
        ].joined(separator: "\n")
    }

    private func setTitle(
        firstPercent: Int?,
        firstReset: String,
        secondPercent: Int?,
        secondReset: String
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.minimumLineHeight = 8
        paragraphStyle.maximumLineHeight = 8

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(
                ofSize: 8,
                weight: .medium
            ),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        let title = NSMutableAttributedString()
        appendLine(
            to: title,
            percent: firstPercent,
            reset: firstReset,
            baseAttributes: baseAttributes
        )
        title.append(NSAttributedString(string: "\n", attributes: baseAttributes))
        appendLine(
            to: title,
            percent: secondPercent,
            reset: secondReset,
            baseAttributes: baseAttributes
        )

        statusLabel.attributedStringValue = title
    }

    private func appendLine(
        to title: NSMutableAttributedString,
        percent: Int?,
        reset: String,
        baseAttributes: [NSAttributedString.Key: Any]
    ) {
        let percentageText = percent.map { "\($0)%" } ?? "--%"
        var percentageAttributes = baseAttributes

        if let percent {
            percentageAttributes[.foregroundColor] = color(for: percent)
        }

        title.append(
            NSAttributedString(
                string: percentageText,
                attributes: percentageAttributes
            )
        )
        title.append(
            NSAttributedString(
                string: " \(reset)",
                attributes: baseAttributes
            )
        )
    }

    private func color(for remainingPercent: Int) -> NSColor {
        if remainingPercent < 5 {
            return .systemRed
        }

        if remainingPercent < 15 {
            return .systemYellow
        }

        return .labelColor
    }

    @objc
    private func refresh() {
        monitor.refresh()
        showRefreshFeedback()
    }

    private func showRefreshFeedback() {
        refreshMenuItem?.title = "Refreshed just now"
        statusLabel.alphaValue = 0.35

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            statusLabel.alphaValue = 1

            try? await Task.sleep(for: .seconds(4))
            refreshMenuItem?.title = "Refresh"
        }
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private extension Date {
    var formattedResetTime: String {
        Self.resetTimeFormatter.string(from: self)
    }

    var formattedResetDay: String {
        Self.resetDayFormatter.string(from: self)
    }

    private static let resetTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let resetDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM"
        return formatter
    }()
}
