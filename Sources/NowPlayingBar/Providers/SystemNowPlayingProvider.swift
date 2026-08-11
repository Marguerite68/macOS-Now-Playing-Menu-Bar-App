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
            scriptName: "ReadMusic"
        ),
        ScriptMediaSource(
            bundleIdentifier: "com.spotify.client",
            scriptName: "ReadSpotify"
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

        let output = try await AppleScriptRunner.run(scriptURL: scriptURL)
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
    nonisolated static func run(scriptURL: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [scriptURL.path]
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
            maxSplits: 5,
            omittingEmptySubsequences: false
        ).map(String.init)
        guard fields.count == 6, !fields[3].isEmpty else { return nil }

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
        self.init(
            id: "\(fields[0]):\(fields[2].isEmpty ? fallbackID : fields[2])",
            title: fields[3],
            artist: fields[4].isEmpty ? nil : fields[4],
            album: fields[5].isEmpty ? nil : fields[5],
            application: application,
            playbackState: playbackState
        )
    }
}
