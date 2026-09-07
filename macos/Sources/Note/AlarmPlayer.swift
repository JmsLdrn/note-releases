import AppKit

/// Loops a system alert sound until it is stopped explicitly.
final class AlarmPlayer {
    private var sound: NSSound?

    /// Called when the alarm stops for any reason, so the UI can drop back to idle.
    var onStop: (() -> Void)?

    private(set) var isRinging = false

    func start(soundNamed name: String) {
        stop()

        // Fall back to the user's alert sound if the named one has been removed.
        let sound = NSSound(named: name) ?? NSSound(named: "Submarine")
        sound?.loops = true
        self.sound = sound

        if sound?.play() != true {
            NSSound.beep()
        }
        isRinging = true
    }

    func stop() {
        sound?.stop()
        sound = nil
        guard isRinging else { return }
        isRinging = false
        onStop?()
    }
}
