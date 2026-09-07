import AVFoundation
import Foundation

/// Owns an imported copy so moving the original music file does not break alarms.
struct CustomAlarmStore {
    static let supportedExtensions = ["mp3", "wav", "aiff", "aif", "m4a"]
    let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.jmsldrn.note/AlarmSounds", isDirectory: true)
    }

    func importFile(at source: URL) throws -> URL {
        guard Self.supportedExtensions.contains(source.pathExtension.lowercased()) else {
            throw ImportError.unsupportedFormat
        }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(source.pathExtension.lowercased())
        do {
            try fileManager.copyItem(at: source, to: destination)
            let player = try AVAudioPlayer(contentsOf: destination)
            guard player.duration > 0, player.prepareToPlay() else { throw ImportError.unplayable }
            return destination
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
    }

    func removeFile(at url: URL?) {
        guard let url, url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    enum ImportError: LocalizedError {
        case unsupportedFormat, unplayable
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "Choose an MP3, WAV, AIFF, or M4A file."
            case .unplayable: return "This audio file could not be played. Choose another file."
            }
        }
    }
}
