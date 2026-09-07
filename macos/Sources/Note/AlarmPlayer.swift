import AppKit
import AVFoundation

/// Loops a system alert sound until it is stopped explicitly.
final class AlarmPlayer {
    private var sound: NSSound?
    private var customPlayer: AVAudioPlayer?

    var isPlaying: Bool { customPlayer?.isPlaying == true || sound?.isPlaying == true }

    /// Called when the alarm stops for any reason, so the UI can drop back to idle.
    var onStop: (() -> Void)?

    private(set) var isRinging = false

    func start(soundNamed name: String, customURL: URL? = nil) {
        stop()

        if let customURL, let player = try? AVAudioPlayer(contentsOf: customURL) {
            player.numberOfLoops = -1
            if player.play() {
                customPlayer = player
                isRinging = true
                return
            }
        }

        // If an imported file becomes unreadable, keep the alarm audible with a built-in sound.
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
        customPlayer?.stop()
        customPlayer = nil
        sound?.stop()
        sound = nil
        guard isRinging else { return }
        isRinging = false
        onStop?()
    }
}
