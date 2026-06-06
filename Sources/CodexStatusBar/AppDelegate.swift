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
            setTitle("--% --:--\n--% --/--")
            return
        }

        let fiveHourRemaining = snapshot.fiveHour.remainingPercent(at: now)
        let weeklyRemaining = snapshot.weekly.remainingPercent(at: now)

        let firstLine = "\(fiveHourRemaining)% \(snapshot.fiveHour.resetDate.formattedResetTime)"
        let secondLine = "\(weeklyRemaining)% \(snapshot.weekly.resetDate.formattedResetDay)"

        setTitle("\(firstLine)\n\(secondLine)")

        statusItem.button?.toolTip = [
            "Codex allowance remaining",
            "Updated \(snapshot.observedAt.formatted(date: .abbreviated, time: .shortened))"
        ].joined(separator: "\n")
    }

    private func setTitle(_ title: String) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.minimumLineHeight = 8
        paragraphStyle.maximumLineHeight = 8

        statusLabel.attributedStringValue = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: 8,
                    weight: .medium
                ),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
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
