import Foundation

/// User-visible options, persisted in UserDefaults so they survive a relaunch.
final class Settings {
    private enum Key {
        static let keepActive = "keepActive"
        static let alarmEnabled = "alarmEnabled"
        static let alarmSound = "alarmSound"
        static let keepDisplayAwake = "keepDisplayAwake"
    }

    static let availableSounds = ["Submarine", "Glass", "Ping", "Sosumi", "Funk", "Hero", "Blow"]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.keepActive: true,
            Key.alarmEnabled: true,
            Key.alarmSound: "Submarine",
            Key.keepDisplayAwake: false
        ])
    }

    /// Post synthetic activity so macOS - and therefore Slack - never sees the Mac as idle.
    var keepActive: Bool {
        get { defaults.bool(forKey: Key.keepActive) }
        set { defaults.set(newValue, forKey: Key.keepActive) }
    }

    /// Sound the alarm when Slack's Dock badge picks up an unread.
    var alarmEnabled: Bool {
        get { defaults.bool(forKey: Key.alarmEnabled) }
        set { defaults.set(newValue, forKey: Key.alarmEnabled) }
    }

    var alarmSound: String {
        get { defaults.string(forKey: Key.alarmSound) ?? "Submarine" }
        set { defaults.set(newValue, forKey: Key.alarmSound) }
    }

    /// Also hold off display sleep. Off by default - staying active in Slack doesn't need the screen on.
    var keepDisplayAwake: Bool {
        get { defaults.bool(forKey: Key.keepDisplayAwake) }
        set { defaults.set(newValue, forKey: Key.keepDisplayAwake) }
    }
}
