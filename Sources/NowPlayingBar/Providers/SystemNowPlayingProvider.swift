import AppKit
import Foundation
import OSLog

@MainActor
final class SystemNowPlayingProvider: MediaProvider {
    let identifier = "system-script-providers"
    var onMediaChanged: ((MediaInfo?) -> Void)?

    private let logger = Logger(subsystem: "com.marguerite.nowplayingbar", category: "NowPlaying")
    private let pollInterval = Duration.seconds(1)
    private var monitoringTask: Task<Void, Never>?
    private var lastPublishedMedia: MediaInfo?

    private let sources = [
        ScriptMediaSource(
            bundleIdentifier: "com.apple.Music",
            scriptName: "ReadMusic",
            exportsArtwork: true
        ),
        ScriptMediaSource(
            bundleIdentifier: "com.spotify.client",
            scriptName: "ReadSpotify",
            exportsArtwork: false
        )
    ]

    func currentMedia() async -> MediaInfo? {
        var pausedCandidate: MediaInfo?

        for source in sources where isApplicationRunning(source.bundleIdentifier) {
            do {
                guard let mediaInfo = try await readMedia(from: source) else { continue }

                if mediaInfo.playbackState == .playing {
                    return mediaInfo
                }
                if pausedCandidate == nil {
                    pausedCandidate = mediaInfo
                }
            } catch {
                logger.error("Failed to read \(source.bundleIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return pausedCandidate
    }

    func startMonitoring() {
        guard monitoringTask == nil else { return }

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let mediaInfo = await self.currentMedia()
                self.publishIfChanged(mediaInfo)

                do {
                    try await Task.sleep(for: self.pollInterval)
                } catch {
                    return
                }
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func isApplicationRunning(_ bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    private func readMedia(from source: ScriptMediaSource) async throws -> MediaInfo? {
        guard let scriptURL = Bundle.main.url(
            forResource: source.scriptName,
            withExtension: "applescript",
            subdirectory: "Scripts"
        ) else {
            throw ScriptMediaError.missingScript(source.scriptName)
        }

        let artworkOutputURL = source.exportsArtwork ? ArtworkCache.musicArtworkURL : nil
        if let artworkOutputURL {
            ArtworkCache.removeArtwork(at: artworkOutputURL)
        }

        let output = try await AppleScriptRunner.run(
            scriptURL: scriptURL,
            arguments: artworkOutputURL.map { [$0.path] } ?? []
        )
        return MediaInfo(scriptOutput: output)
    }

    private func publishIfChanged(_ mediaInfo: MediaInfo?) {
        guard mediaInfo != lastPublishedMedia else { return }
        lastPublishedMedia = mediaInfo
        onMediaChanged?(mediaInfo)
    }
}

private struct ScriptMediaSource {
    let bundleIdentifier: String
    let scriptName: String
    let exportsArtwork: Bool
}

private enum ArtworkCache {
    static var musicArtworkURL: URL {
        let baseDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let artworkDirectory = baseDirectory.appendingPathComponent(
            "NowPlayingBar/Artwork",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: artworkDirectory,
            withIntermediateDirectories: true
        )
        return artworkDirectory.appendingPathComponent("apple-music-current-artwork")
    }

    static func removeArtwork(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

private enum ScriptMediaError: LocalizedError {
    case missingScript(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingScript(let name):
            "Missing bundled AppleScript: \(name)"
        case .executionFailed(let message):
            message
        }
    }
}

private enum AppleScriptRunner {
    nonisolated static func run(scriptURL: URL, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [scriptURL.path] + arguments
            process.standardOutput = standardOutput
            process.standardError = standardError

            try process.run()

            let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
            let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let message = String(data: errorData, encoding: .utf8)
                    ?? "AppleScript failed with status \(process.terminationStatus)"
                throw ScriptMediaError.executionFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            return String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }.value
    }
}

private extension MediaInfo {
    init?(scriptOutput: String) {
        guard !scriptOutput.isEmpty else { return nil }

        let fields = scriptOutput.split(
            separator: "\u{001E}",
            maxSplits: 6,
            omittingEmptySubsequences: false
        ).map(String.init)
        guard (fields.count == 6 || fields.count == 7), !fields[3].isEmpty else { return nil }

        let application: MediaApplication
        switch fields[0] {
        case "appleMusic": application = .appleMusic
        case "spotify": application = .spotify
        default: application = .unknown
        }

        let playbackState: PlaybackState
        switch fields[1].lowercased() {
        case "playing": playbackState = .playing
        case "paused": playbackState = .paused
        case "stopped": playbackState = .stopped
        default: playbackState = .unknown
        }

        let fallbackID = [fields[3], fields[4], fields[5]].joined(separator: "|")
        let artworkURL = fields.count == 7 ? Self.artworkURL(from: fields[6]) : nil
        self.init(
            id: "\(fields[0]):\(fields[2].isEmpty ? fallbackID : fields[2])",
            title: fields[3],
            artist: fields[4].isEmpty ? nil : fields[4],
            album: fields[5].isEmpty ? nil : fields[5],
            artworkURL: artworkURL,
            application: application,
            playbackState: playbackState
        )
    }

    private static func artworkURL(from location: String) -> URL? {
        guard !location.isEmpty else { return nil }
        if location.hasPrefix("/") {
            let url = URL(fileURLWithPath: location)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        guard let url = URL(string: location),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }
        return url
    }
}
