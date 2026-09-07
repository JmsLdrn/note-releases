import AppKit
import ApplicationServices
import CoreGraphics
import IOKit.pwr_mgt

/// Keeps the Mac looking busy.
///
/// Slack decides you are "away" from the system-wide HID idle timer, so a power
/// assertion alone is not enough - it stops sleep but never resets that timer.
/// Two things do reset it, and this posts both on a slow repeating timer:
///
/// 1. `IOPMAssertionDeclareUserActivity`, which tells power management a user is present.
/// 2. A synthetic F15 key press. F15 exists on no modern keyboard, produces no text and is
///    bound to nothing, so it is invisible to whatever app happens to be focused.
final class ActivityKeeper {
    /// How often to nudge. Slack allows roughly ten idle minutes, so two is comfortable.
    private let interval: TimeInterval

    private var timer: Timer?
    private var userActivityID = IOPMAssertionID(0)
    private var displayAssertionID = IOPMAssertionID(0)
    private var holdsDisplayAssertion = false

    private(set) var isRunning = false

    init(interval: TimeInterval = 120) {
        self.interval = interval
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true

        nudge()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.nudge()
        }
        // A tolerance lets the timer coalesce with other wake-ups; precision buys us nothing here.
        timer.tolerance = interval / 4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        releaseDisplayAssertion()
    }

    /// Seconds since the last real *or* synthetic input event - what Slack is watching.
    ///
    /// Asking for "any event type" means force-unwrapping a raw value that `CGEventType`
    /// has no case for, so take the minimum over the types a person actually generates.
    var secondsSinceLastEvent: TimeInterval {
        let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .flagsChanged, .scrollWheel]
        return types
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min() ?? 0
    }

    // MARK: - Display sleep

    func setKeepDisplayAwake(_ keepAwake: Bool) {
        if keepAwake {
            guard !holdsDisplayAssertion else { return }
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Note is keeping you active in Slack" as CFString,
                &displayAssertionID
            )
            holdsDisplayAssertion = (result == kIOReturnSuccess)
        } else {
            releaseDisplayAssertion()
        }
    }

    private func releaseDisplayAssertion() {
        guard holdsDisplayAssertion else { return }
        IOPMAssertionRelease(displayAssertionID)
        displayAssertionID = IOPMAssertionID(0)
        holdsDisplayAssertion = false
    }

    // MARK: - The nudge

    private func nudge() {
        // Reusing the same assertion ID on every call is what the API asks for; it updates
        // the existing declaration instead of stacking up a new one each time.
        IOPMAssertionDeclareUserActivity(
            "Note is keeping you active in Slack" as CFString,
            kIOPMUserActiveLocal,
            &userActivityID
        )

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let f15: CGKeyCode = 113
        let down = CGEvent(keyboardEventSource: source, virtualKey: f15, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: f15, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - Permissions

    /// Posting synthetic events needs Accessibility, same as reading Slack's Dock badge.
    static var isTrustedForAccessibility: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityTrust() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
