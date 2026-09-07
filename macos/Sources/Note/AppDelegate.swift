import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let keeper = ActivityKeeper()
    private let watcher = SlackWatcher()
    private let alarm = AlarmPlayer()

    private var statusItem: NSStatusItem!
    private var statusHeaderItem: NSMenuItem!
    private var keepActiveItem: NSMenuItem!
    private var alarmEnabledItem: NSMenuItem!
    private var keepDisplayAwakeItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var stopAlarmItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var soundMenu: NSMenu!

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()

        alarm.onStop = { [weak self] in
            self?.refreshUI()
        }

        watcher.onNewMessage = { [weak self] badge in
            self?.handleNewMessage(badge: badge)
        }
        watcher.onStatusChange = { [weak self] _ in
            self?.refreshUI()
        }
        watcher.start()

        if settings.keepActive {
            keeper.start()
        }
        keeper.setKeepDisplayAwake(settings.keepActive && settings.keepDisplayAwake)

        // Both halves of the app - posting activity and reading the Dock badge - need
        // Accessibility, so ask once at launch rather than failing quietly.
        if !ActivityKeeper.isTrustedForAccessibility {
            ActivityKeeper.requestAccessibilityTrust()
        }

        refreshUI()
    }

    func applicationWillTerminate(_ notification: Notification) {
        alarm.stop()
        watcher.stop()
        keeper.stop()
    }

    // MARK: - Menu

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        Self.applyStatusImage(symbol("bell"), to: statusItem)

        let menu = NSMenu()
        menu.delegate = self
        // Drive enablement from refreshUI() instead of the responder chain.
        menu.autoenablesItems = false

        statusHeaderItem = NSMenuItem(title: "Starting up…", action: nil, keyEquivalent: "")
        statusHeaderItem.isEnabled = false
        menu.addItem(statusHeaderItem)

        permissionItem = NSMenuItem(
            title: "Grant Accessibility permission…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

        menu.addItem(.separator())

        keepActiveItem = addItem(to: menu, title: "Keep me active in Slack", action: #selector(toggleKeepActive))
        alarmEnabledItem = addItem(to: menu, title: "Alarm on new message", action: #selector(toggleAlarmEnabled))
        keepDisplayAwakeItem = addItem(to: menu, title: "Also keep the display awake", action: #selector(toggleKeepDisplayAwake))

        let soundItem = NSMenuItem(title: "Alarm sound", action: nil, keyEquivalent: "")
        soundMenu = NSMenu()
        for name in Settings.availableSounds {
            let item = NSMenuItem(title: name, action: #selector(selectSound(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            soundMenu.addItem(item)
        }
        soundItem.submenu = soundMenu
        menu.addItem(soundItem)

        menu.addItem(.separator())

        stopAlarmItem = addItem(to: menu, title: "Stop alarm", action: #selector(stopAlarm))
        addItem(to: menu, title: "Test alarm", action: #selector(testAlarm))

        menu.addItem(.separator())

        launchAtLoginItem = addItem(to: menu, title: "Launch at login", action: #selector(toggleLaunchAtLogin))
        addItem(to: menu, title: "Quit Note", action: #selector(quit), keyEquivalent: "q")

        statusItem.menu = menu
    }

    @discardableResult
    private func addItem(to menu: NSMenu, title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        menu.addItem(item)
        return item
    }

    private func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: "Note")
    }

    /// Keep a visible, clickable item even if a symbol is unavailable on this OS.
    static func applyStatusImage(_ image: NSImage?, to item: NSStatusItem) {
        guard let button = item.button else { return }
        image?.isTemplate = true
        button.image = image
        button.title = image == nil ? "●" : ""
        button.imagePosition = image == nil ? .noImage : .imageOnly
        button.setAccessibilityLabel("Note")
        button.toolTip = "Note"
        // A minimum width also protects the fallback from a zero-width layout.
        item.length = max(NSStatusBar.system.thickness, button.fittingSize.width)
    }

    // MARK: - Actions

    @objc private func toggleKeepActive() {
        settings.keepActive.toggle()
        if settings.keepActive {
            keeper.start()
        } else {
            keeper.stop()
        }
        keeper.setKeepDisplayAwake(settings.keepActive && settings.keepDisplayAwake)
        refreshUI()
    }

    @objc private func toggleAlarmEnabled() {
        settings.alarmEnabled.toggle()
        if !settings.alarmEnabled {
            alarm.stop()
        }
        refreshUI()
    }

    @objc private func toggleKeepDisplayAwake() {
        settings.keepDisplayAwake.toggle()
        keeper.setKeepDisplayAwake(settings.keepActive && settings.keepDisplayAwake)
        refreshUI()
    }

    @objc private func selectSound(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        settings.alarmSound = name
        refreshUI()
    }

    @objc private func stopAlarm() {
        alarm.stop()
        watcher.acknowledgeCurrentBadge()
        refreshUI()
    }

    @objc private func testAlarm() {
        alarm.start(soundNamed: settings.alarmSound, timeout: 5)
        refreshUI()
    }

    @objc private func openAccessibilitySettings() {
        // Re-prompt first: if the app has never been added to the list, this puts it there.
        ActivityKeeper.requestAccessibilityTrust()
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            presentError("Could not change the login item", error.localizedDescription)
        }
        refreshUI()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Alarm

    private func handleNewMessage(badge: String) {
        guard settings.alarmEnabled else { return }
        alarm.start(soundNamed: settings.alarmSound, timeout: settings.alarmTimeout)
        refreshUI()
    }

    // MARK: - UI state

    private func refreshUI() {
        let iconName: String
        if alarm.isRinging {
            iconName = "bell.badge.fill"
        } else if settings.keepActive {
            iconName = "bell"
        } else {
            iconName = "bell.slash"
        }
        Self.applyStatusImage(symbol(iconName), to: statusItem)

        statusHeaderItem.title = headerTitle()

        let needsPermission = !ActivityKeeper.isTrustedForAccessibility
        permissionItem.isHidden = !needsPermission

        keepActiveItem.state = settings.keepActive ? .on : .off
        alarmEnabledItem.state = settings.alarmEnabled ? .on : .off
        keepDisplayAwakeItem.state = settings.keepDisplayAwake ? .on : .off
        keepDisplayAwakeItem.isEnabled = settings.keepActive
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        stopAlarmItem.isEnabled = alarm.isRinging

        for item in soundMenu.items {
            item.state = (item.representedObject as? String) == settings.alarmSound ? .on : .off
        }
    }

    private func headerTitle() -> String {
        if alarm.isRinging {
            return "New Slack message"
        }
        switch watcher.status {
        case .noAccessibilityPermission:
            return "Needs Accessibility permission"
        case .notRunning:
            return "Slack is not running"
        case .running(let badge):
            guard let badge else {
                return settings.keepActive ? "Active in Slack - no unreads" : "Paused - no unreads"
            }
            return settings.keepActive ? "Active in Slack - \(badge) unread" : "Paused - \(badge) unread"
        }
    }

    private func presentError(_ message: String, _ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }
}

extension AppDelegate: NSMenuDelegate {
    /// The badge and the permission state can both change while the app sits idle,
    /// so re-read them as the menu opens rather than only on a poll tick.
    func menuWillOpen(_ menu: NSMenu) {
        refreshUI()
    }
}
