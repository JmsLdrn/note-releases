import AppKit

/// Loops a system alert sound until it is dismissed, or until the timeout runs out
/// so a Mac left alone does not ring forever.
final class AlarmPlayer {
    private var sound: NSSound?
    private var timeoutTimer: Timer?

    /// Called when the alarm stops for any reason, so the UI can drop back to idle.
    var onStop: (() -> Void)?

    private(set) var isRinging = false

    func start(soundNamed name: String, timeout: TimeInterval) {
        stop()

        // Fall back to the user's alert sound if the named one has been removed.
        let sound = NSSound(named: name) ?? NSSound(named: "Submarine")
        sound?.loops = true
        self.sound = sound

        if sound?.play() != true {
            NSSound.beep()
        }
        isRinging = true

        if timeout > 0 {
            let timer = Timer(timeInterval: timeout, repeats: false) { [weak self] _ in
                self?.stop()
            }
            RunLoop.main.add(timer, forMode: .common)
            timeoutTimer = timer
        }
    }

    func stop() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        sound?.stop()
        sound = nil
        guard isRinging else { return }
        isRinging = false
        onStop?()
    }
}
