import AppKit
import CodexStatusCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let fiveHourDisplayModeKey = "fiveHourLimitDisplayMode"
    private static let twoLimitWidth: CGFloat = 59
    private static let singleLimitWidth: CGFloat = 32

    private let monitor = UsageMonitor()
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: AppDelegate.twoLimitWidth
    )
    private let statusLabel = NSTextField(labelWithString: "")
    private var statusLabelCenterYConstraint: NSLayoutConstraint?
    private var fiveHourDisplayMode: FiveHourLimitDisplayMode = .show
    private var fiveHourDisplayMenuItems: [FiveHourLimitDisplayMode: NSMenuItem] = [:]
    private var latestSnapshot: UsageSnapshot?
    private var refreshMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        fiveHourDisplayMode = savedFiveHourDisplayMode()
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

        let centerYConstraint = statusLabel.centerYAnchor.constraint(
            equalTo: button.centerYAnchor,
            constant: 1.5
        )
        statusLabelCenterYConstraint = centerYConstraint

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            centerYConstraint
        ])

        let menu = NSMenu()
        let refreshMenuItem = menu.addItem(
            withTitle: "Refresh",
            action: #selector(refresh),
            keyEquivalent: "r"
        )
        self.refreshMenuItem = refreshMenuItem
        menu.addItem(makeFiveHourDisplayMenuItem())
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Codex Status Bar",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    private func makeFiveHourDisplayMenuItem() -> NSMenuItem {
        let parentItem = NSMenuItem(title: "5h Limit", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "5h Limit")

        addDisplayMode(.show, title: "Show", to: submenu)
        addDisplayMode(.hide, title: "Hide", to: submenu)
        addDisplayMode(.dynamic, title: "Dynamic", to: submenu)
        updateDisplayModeMenuState()

        parentItem.submenu = submenu
        return parentItem
    }

    private func addDisplayMode(
        _ mode: FiveHourLimitDisplayMode,
        title: String,
        to menu: NSMenu
    ) {
        let item = menu.addItem(
            withTitle: title,
            action: #selector(selectFiveHourDisplayMode(_:)),
            keyEquivalent: ""
        )
        item.representedObject = mode.rawValue
        item.target = self
        fiveHourDisplayMenuItems[mode] = item
    }

    private func updateTitle(snapshot: UsageSnapshot?, now: Date) {
        latestSnapshot = snapshot

        let shouldShowFiveHour = fiveHourDisplayMode.shouldShow(
            hasLimit: snapshot?.fiveHour != nil
        )

        guard let snapshot else {
            setTitle(
                firstPercent: nil,
                firstReset: "--:--",
                secondPercent: nil,
                secondReset: "--/--",
                showsFirstLine: shouldShowFiveHour
            )
            return
        }

        let fiveHourRemaining = snapshot.fiveHour?.remainingPercent(at: now)
        let weeklyRemaining = snapshot.weekly?.remainingPercent(at: now)

        setTitle(
            firstPercent: fiveHourRemaining,
            firstReset: snapshot.fiveHour?.resetDate.formattedResetTime ?? "--:--",
            secondPercent: weeklyRemaining,
            secondReset: snapshot.weekly?.resetDate.formattedResetDay ?? "--/--",
            showsFirstLine: shouldShowFiveHour
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
        secondReset: String,
        showsFirstLine: Bool
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.minimumLineHeight = showsFirstLine ? 8 : 10
        paragraphStyle.maximumLineHeight = showsFirstLine ? 8 : 10

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(
                ofSize: 8,
                weight: .medium
            ),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        let title = NSMutableAttributedString()
        if showsFirstLine {
            statusItem.length = Self.twoLimitWidth
            statusLabelCenterYConstraint?.constant = 1.5
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
        } else {
            statusItem.length = Self.singleLimitWidth
            statusLabelCenterYConstraint?.constant = -0.5
            appendStackedLimit(
                to: title,
                percent: secondPercent,
                reset: secondReset,
                baseAttributes: baseAttributes
            )
        }

        statusLabel.attributedStringValue = title
    }

    private func appendStackedLimit(
        to title: NSMutableAttributedString,
        percent: Int?,
        reset: String,
        baseAttributes: [NSAttributedString.Key: Any]
    ) {
        title.append(NSAttributedString(string: reset, attributes: baseAttributes))
        title.append(NSAttributedString(string: "\n", attributes: baseAttributes))
        appendPercentage(
            to: title,
            percent: percent,
            baseAttributes: baseAttributes
        )
    }

    private func savedFiveHourDisplayMode() -> FiveHourLimitDisplayMode {
        let savedValue = UserDefaults.standard.string(
            forKey: Self.fiveHourDisplayModeKey
        )

        guard let savedValue else {
            return .show
        }

        return FiveHourLimitDisplayMode(rawValue: savedValue) ?? .show
    }

    private func updateDisplayModeMenuState() {
        for (mode, item) in fiveHourDisplayMenuItems {
            item.state = mode == fiveHourDisplayMode ? .on : .off
        }
    }

    private func appendLine(
        to title: NSMutableAttributedString,
        percent: Int?,
        reset: String,
        baseAttributes: [NSAttributedString.Key: Any]
    ) {
        appendPercentage(
            to: title,
            percent: percent,
            baseAttributes: baseAttributes
        )
        title.append(
            NSAttributedString(
                string: " \(reset)",
                attributes: baseAttributes
            )
        )
    }

    private func appendPercentage(
        to title: NSMutableAttributedString,
        percent: Int?,
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
    private func selectFiveHourDisplayMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String else {
            return
        }

        guard let mode = FiveHourLimitDisplayMode(rawValue: rawValue) else {
            return
        }

        fiveHourDisplayMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.fiveHourDisplayModeKey)
        updateDisplayModeMenuState()
        updateTitle(snapshot: latestSnapshot, now: Date())
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
