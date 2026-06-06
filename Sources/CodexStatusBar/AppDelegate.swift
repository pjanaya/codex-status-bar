import AppKit
import CodexStatusCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = UsageMonitor()
    private let statusItem = NSStatusBar.system.statusItem(withLength: 68)

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
        button.cell?.wraps = true
        button.cell?.lineBreakMode = .byClipping

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Refresh",
            action: #selector(refresh),
            keyEquivalent: "r"
        )
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

        statusItem.button?.attributedTitle = NSAttributedString(
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
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private extension Date {
    var formattedResetTime: String {
        formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    var formattedResetDay: String {
        formatted(
            Date.FormatStyle()
                .day(.twoDigits)
                .month(.twoDigits)
        )
    }
}
