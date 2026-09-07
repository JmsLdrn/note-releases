import AppKit
import ApplicationServices

/// Watches Slack's Dock badge and reports the moment it grows.
///
/// Reading the badge is the one signal that needs no Slack token, no workspace admin
/// and no Full Disk Access - just the Accessibility permission the activity nudge
/// already requires. The badge is the same number Slack itself decides to show you,
/// so the alarm follows your Slack notification preferences for free.
final class SlackWatcher {
    enum Status: Equatable {
        case notRunning
        case running(badge: String?)
        case noAccessibilityPermission
    }

    /// Fired when the badge appears or its count goes up. Carries the badge text ("3", "•").
    var onNewMessage: ((String) -> Void)?
    /// Fired whenever the observed status changes, for the menu bar.
    var onStatusChange: ((Status) -> Void)?

    private let slackBundleID = "com.tinyspeck.slackmacgap"
    private let dockBundleID = "com.apple.dock"
    private let pollInterval: TimeInterval

    private var timer: Timer?
    private var lastBadge: String?
    private var lastStatus: Status?

    private(set) var isRunning = false

    init(pollInterval: TimeInterval = 2) {
        self.pollInterval = pollInterval
    }

    deinit {
        stop()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        poll()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = pollInterval / 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        lastBadge = nil
        lastStatus = nil
    }

    /// Forget the current badge, so an unread that is already on screen does not
    /// re-trigger the alarm after the user dismisses it.
    func acknowledgeCurrentBadge() {
        lastBadge = currentBadge()
    }

    var status: Status {
        guard AXIsProcessTrusted() else { return .noAccessibilityPermission }
        guard isSlackRunning else { return .notRunning }
        return .running(badge: currentBadge())
    }

    // MARK: - Polling

    private func poll() {
        let status = self.status
        if status != lastStatus {
            lastStatus = status
            onStatusChange?(status)
        }

        switch status {
        case .notRunning, .noAccessibilityPermission:
            lastBadge = nil
        case .running(let badge):
            defer { lastBadge = badge }
            guard let badge, badge != lastBadge, isNewMessage(previous: lastBadge, current: badge) else { return }
            onNewMessage?(badge)
        }
    }

    /// A badge that appears from nothing, or a count that climbs, is a new message.
    /// A count that drops means the user is reading, not that more arrived.
    private func isNewMessage(previous: String?, current: String) -> Bool {
        guard let previous else { return true }
        guard let previousCount = Int(previous), let currentCount = Int(current) else {
            // Non-numeric badges (Slack shows "•" for unreads without a mention) carry no
            // count, so any change from one to another is treated as fresh activity.
            return true
        }
        return currentCount > previousCount
    }

    private var isSlackRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: slackBundleID).isEmpty
    }

    // MARK: - Dock badge

    private func currentBadge() -> String? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleID).first else {
            return nil
        }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        return findBadge(in: dockElement, depth: 0)
    }

    /// The Dock nests its app buttons inside an AXList, and the exact nesting has moved
    /// between macOS releases, so walk a couple of levels rather than hard-coding a path.
    private func findBadge(in element: AXUIElement, depth: Int) -> String? {
        guard depth <= 3, let children = children(of: element) else { return nil }
        for child in children {
            if let title = string(child, kAXTitleAttribute), title == "Slack" {
                if let badge = string(child, "AXStatusLabel"), !badge.isEmpty {
                    return badge
                }
                // Slack is on the Dock but carries no badge right now.
                return nil
            }
            if let badge = findBadge(in: child, depth: depth + 1) {
                return badge
            }
        }
        return nil
    }

    private func children(of element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }
}
