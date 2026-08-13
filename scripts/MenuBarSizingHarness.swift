import Darwin
import Foundation

@main
@MainActor
struct MenuBarSizingHarness {
    static func main() async {
        let text = "Blinding Lights · The Weeknd"
        let metrics = MarqueeMetrics.menuBar(text: text)
        guard metrics.textWidth > 0,
              metrics.viewportWidth > 0,
              metrics.viewportWidth <= MenuBarLayout.maximumTextWidth else {
            fputs("FAIL: menu-bar text metrics are invalid\n", stderr)
            exit(1)
        }

        let artworkURL = URL(string: "https://example.com/cover.jpg")!
        let mediaInfo = MediaInfo(
            id: "display-mode-test",
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            artworkURL: artworkURL,
            application: .appleMusic,
            playbackState: .playing
        )

        guard mediaInfo.replacingPlaybackState(with: .paused).artworkURL == artworkURL else {
            fputs("FAIL: changing playback state discarded the artwork URL\n", stderr)
            exit(1)
        }

        guard MenuBarDisplayMode.iconOnly.text(for: mediaInfo) == nil else {
            fputs("FAIL: icon-only mode emitted text\n", stderr)
            exit(1)
        }

        guard MenuBarDisplayMode.title.text(for: mediaInfo) == "Blinding Lights" else {
            fputs("FAIL: title mode did not emit the title\n", stderr)
            exit(1)
        }

        guard MenuBarDisplayMode.titleAndArtist.text(for: mediaInfo)
            == "Blinding Lights · The Weeknd" else {
            fputs("FAIL: title-and-artist mode emitted the wrong text\n", stderr)
            exit(1)
        }

        guard MenuBarDisplayMode.title.text(for: nil) == nil else {
            fputs("FAIL: no-media state emitted placeholder text\n", stderr)
            exit(1)
        }

        let visibleIdlePresentation = StatusBarPresentation(
            mediaInfo: nil,
            displayMode: .title,
            hideStatusItemWhenNoMedia: false
        )
        guard !visibleIdlePresentation.isHidden,
              visibleIdlePresentation.iconName == "zzz",
              visibleIdlePresentation.statusItemLength == 24 else {
            fputs("FAIL: idle status item did not retain its icon\n", stderr)
            exit(1)
        }

        let hiddenIdlePresentation = StatusBarPresentation(
            mediaInfo: nil,
            displayMode: .title,
            hideStatusItemWhenNoMedia: true
        )
        guard hiddenIdlePresentation.isHidden,
              hiddenIdlePresentation.statusItemLength == 0 else {
            fputs("FAIL: hide-when-idle setting did not hide the status item\n", stderr)
            exit(1)
        }

        let presentation = StatusBarPresentation(
            mediaInfo: mediaInfo,
            displayMode: .titleAndArtist,
            hideStatusItemWhenNoMedia: false
        )
        guard presentation.title == "Blinding Lights · The Weeknd",
              presentation.iconName == "music.note",
              presentation.shouldScroll,
              presentation.statusItemLength > 100 else {
            fputs("FAIL: status-item presentation omitted the title\n", stderr)
            exit(1)
        }

        let truncatedPresentation = StatusBarPresentation(
            mediaInfo: mediaInfo,
            displayMode: .titleAndArtist,
            hideStatusItemWhenNoMedia: false,
            maximumCharacters: 10,
            scrollingEnabled: false
        )
        let expectedTruncation = String(mediaInfo.menuBarText.prefix(10)) + "…"
        guard truncatedPresentation.title == expectedTruncation,
              !truncatedPresentation.shouldScroll else {
            fputs("FAIL: disabled scrolling did not truncate at the character limit\n", stderr)
            exit(1)
        }

        guard let loopPlan = MarqueeAnimationPlan.make(
            travelDistance: 100,
            mode: .loop,
            pointsPerSecond: 20
        ), loopPlan.values == [0, -100],
           loopPlan.duration == 5 else {
            fputs("FAIL: loop animation jumps instead of crossing its repeat boundary seamlessly\n", stderr)
            exit(1)
        }

        let seamlessLoopContent = MarqueeContentLayout.make(
            text: "Now Playing",
            viewportWidth: 60,
            mode: .loop,
            fontWeight: .medium
        )
        guard seamlessLoopContent.renderedText
            == "Now Playing\(MarqueeContentLayout.loopSeparator)Now Playing",
              seamlessLoopContent.travelDistance > 0 else {
            fputs("FAIL: loop mode does not render adjacent text copies\n", stderr)
            exit(1)
        }

        guard let pingPongPlan = MarqueeAnimationPlan.make(
            travelDistance: 100,
            mode: .pingPong,
            pointsPerSecond: 20
        ), pingPongPlan.values == [0, 0, -100, -100, 0],
           pingPongPlan.duration == 12.4 else {
            fputs("FAIL: ping-pong animation does not pause at both ends\n", stderr)
            exit(1)
        }

        let provider = HarnessMediaProvider()
        let manager = NowPlayingManager(provider: provider)
        let settings = AppSettings(
            transientDisplayMode: .titleAndArtist,
            hideStatusItemWhenNoMedia: false
        )
        var observedPresentation: StatusBarPresentation?
        let observer = StatusBarPresentationObserver(
            manager: manager,
            settings: settings
        ) { observedPresentation = $0 }

        guard observedPresentation?.isHidden == false else {
            fputs("FAIL: default idle setting unexpectedly hid the status item\n", stderr)
            exit(1)
        }

        let isolatedDefaults = UserDefaults(suiteName: "NowPlayingBar-test-\(UUID().uuidString)")!
        let defaultSettings = AppSettings(defaults: isolatedDefaults)
        guard defaultSettings.hideStatusItemWhenNoMedia == false else {
            fputs("FAIL: hide-when-idle setting is not off by default\n", stderr)
            exit(1)
        }
        guard defaultSettings.audioQualityRecognitionEnabled == false else {
            fputs("FAIL: audio-quality recognition is not off by default\n", stderr)
            exit(1)
        }

        guard AudioQualityDetailsState(
            recognitionEnabled: false,
            quality: nil,
            unavailableReason: .noPlaybackEvidence
        ) == .hidden else {
            fputs("FAIL: disabled recognition still exposed quality details\n", stderr)
            exit(1)
        }
        guard DetailsPanelLayout.height(recognitionEnabled: true) < 154,
              DetailsPanelLayout.artworkSize(recognitionEnabled: true) > 84,
              DetailsPanelLayout.height(recognitionEnabled: true)
                == DetailsPanelLayout.artworkSize(recognitionEnabled: true)
                    + DetailsPanelLayout.padding(recognitionEnabled: true) * 2 else {
            fputs("FAIL: quality detail layout does not use equal outer spacing\n", stderr)
            exit(1)
        }

        let shortDetailsMedia = MediaInfo(
            id: "short-details",
            title: "Year N",
            artist: "Mii",
            album: "Year N - Single",
            application: .appleMusic,
            playbackState: .playing
        )
        let longDetailsMedia = MediaInfo(
            id: "long-details",
            title: String(repeating: "A long title for the details panel ", count: 4),
            artist: "A long artist name for the details panel",
            album: "A long album name for the details panel",
            application: .appleMusic,
            playbackState: .playing
        )
        let shortDetailsWidth = DetailsPanelLayout.width(
            for: shortDetailsMedia,
            recognitionEnabled: true
        )
        let longDetailsWidth = DetailsPanelLayout.width(
            for: longDetailsMedia,
            recognitionEnabled: true
        )
        guard shortDetailsWidth < longDetailsWidth,
              longDetailsWidth == DetailsPanelLayout.maximumWidth,
              DetailsPanelLayout.metadataArtworkSpacing == 16 else {
            fputs("FAIL: details-panel width does not adapt to metadata length\n", stderr)
            exit(1)
        }

        let losslessQuality = VerifiedAudioQuality(
            tier: .lossless,
            sampleRate: 44_100,
            bitDepth: 16,
            bitRate: nil,
            evidenceDescription: "无损",
            providerIdentifier: "harness"
        )
        let qualityPresentation = StatusBarPresentation(
            mediaInfo: mediaInfo,
            displayMode: .title,
            audioQuality: losslessQuality
        )
        guard qualityPresentation.qualityBadge == .lossless,
              qualityPresentation.qualityBadgeWidth > 0,
              qualityPresentation.statusItemLength > presentation.statusItemLength - 100 else {
            fputs("FAIL: verified quality did not produce a menu-bar badge\n", stderr)
            exit(1)
        }

        let iconOnlyQualityPresentation = StatusBarPresentation(
            mediaInfo: mediaInfo,
            displayMode: .iconOnly,
            audioQuality: losslessQuality
        )
        guard iconOnlyQualityPresentation.statusItemLength
                >= MenuBarLayout.horizontalPadding * 2
                    + MenuBarLayout.iconWidth
                    + iconOnlyQualityPresentation.qualityBadgeWidth else {
            fputs("FAIL: icon-only quality badge overlaps the media icon\n", stderr)
            exit(1)
        }

        let parsedHiRes = AppleMusicAccessibilityQualityProvider.parseQuality(
            from: ["Hi-Res Lossless", "24-bit / 96 kHz"],
            providerIdentifier: "harness"
        )
        guard parsedHiRes?.tier == .hiResLossless,
              parsedHiRes?.bitDepth == 24,
              parsedHiRes?.sampleRate == 96_000 else {
            fputs("FAIL: Hi-Res accessibility evidence was parsed incorrectly\n", stderr)
            exit(1)
        }

        guard AppleMusicAccessibilityQualityProvider.parseQuality(
            from: ["24-bit / 96 kHz"],
            providerIdentifier: "harness"
        ) == nil else {
            fputs("FAIL: resolution without lossless evidence produced a badge\n", stderr)
            exit(1)
        }

        let backgroundProvider = SequenceAudioQualityProvider(results: [
            .verified(losslessQuality),
            .unavailable(.providerUnavailable)
        ])
        let backgroundSettings = AppSettings(
            transientDisplayMode: .title,
            audioQualityRecognitionEnabled: true
        )
        let backgroundMediaProvider = HarnessMediaProvider()
        let backgroundMediaManager = NowPlayingManager(provider: backgroundMediaProvider)
        let backgroundQualityManager = AudioQualityManager(
            mediaManager: backgroundMediaManager,
            settings: backgroundSettings,
            provider: backgroundProvider,
            isAccessibilityTrusted: { true }
        )
        backgroundMediaProvider.publish(mediaInfo)
        try? await Task.sleep(for: .milliseconds(500))
        await backgroundQualityManager.refresh()
        guard backgroundQualityManager.quality == losslessQuality else {
            fputs("FAIL: closing the Music window discarded verified quality for the same track\n", stderr)
            exit(1)
        }
        let nextTrack = MediaInfo(
            id: "next-track",
            title: "Next Track",
            artist: "Artist",
            album: nil,
            application: .appleMusic,
            playbackState: .playing
        )
        backgroundMediaProvider.publish(nextTrack)
        guard backgroundQualityManager.quality == nil else {
            fputs("FAIL: cached quality leaked into the next background track\n", stderr)
            exit(1)
        }

        let pauseProvider = PlaybackStateAudioQualityProvider(quality: losslessQuality)
        let pauseSettings = AppSettings(
            transientDisplayMode: .title,
            audioQualityRecognitionEnabled: true
        )
        let pauseMediaProvider = HarnessMediaProvider()
        let pauseMediaManager = NowPlayingManager(provider: pauseMediaProvider)
        let pauseQualityManager = AudioQualityManager(
            mediaManager: pauseMediaManager,
            settings: pauseSettings,
            provider: pauseProvider,
            isAccessibilityTrusted: { true }
        )
        pauseMediaProvider.publish(mediaInfo)
        await pauseQualityManager.refresh()
        pauseMediaProvider.publish(mediaInfo.replacingPlaybackState(with: .paused))
        await pauseQualityManager.refresh()
        guard pauseQualityManager.quality == losslessQuality else {
            fputs("FAIL: pausing discarded verified quality for the current track\n", stderr)
            exit(1)
        }

        settings.hideStatusItemWhenNoMedia = true
        guard observedPresentation?.isHidden == true else {
            fputs("FAIL: live hide-when-idle setting used a stale value\n", stderr)
            exit(1)
        }

        settings.hideStatusItemWhenNoMedia = false

        provider.publish(mediaInfo)
        guard observedPresentation?.title == "Blinding Lights · The Weeknd",
              observedPresentation?.iconName == "music.note" else {
            fputs("FAIL: status item used the previous media state\n", stderr)
            exit(1)
        }

        settings.displayMode = .iconOnly
        guard observedPresentation?.title.isEmpty == true else {
            fputs("FAIL: icon-only selection used the previous display mode\n", stderr)
            exit(1)
        }

        settings.displayMode = .title
        guard observedPresentation?.title == "Blinding Lights" else {
            fputs("FAIL: title selection used the previous display mode\n", stderr)
            exit(1)
        }

        settings.maximumCharacters = 8
        settings.scrollingEnabled = false
        guard observedPresentation?.title == String(mediaInfo.title.prefix(8)) + "…",
              observedPresentation?.shouldScroll == false else {
            fputs("FAIL: live character-limit settings used stale values\n", stderr)
            exit(1)
        }

        settings.scrollingEnabled = true
        settings.marqueeMode = .pingPong
        settings.scrollingSpeed = 42
        settings.fontWeight = .bold
        guard observedPresentation?.title == mediaInfo.title,
              observedPresentation?.shouldScroll == true,
              observedPresentation?.marqueeMode == .pingPong,
              observedPresentation?.scrollingSpeed == 42,
              observedPresentation?.fontWeight == .bold else {
            fputs("FAIL: live marquee settings used stale values\n", stderr)
            exit(1)
        }

        provider.publish(mediaInfo.replacingPlaybackState(with: .paused))
        guard observedPresentation?.iconName == "pause.fill" else {
            fputs("FAIL: pause icon used the previous playback state\n", stderr)
            exit(1)
        }

        withExtendedLifetime(observer) {}

        print("PASS: marquee size, display modes, and status-item presentation are valid")
    }
}

private actor SequenceAudioQualityProvider: AudioQualityProvider {
    let identifier = "sequence-harness"
    private var results: [AudioQualityProviderResult]

    init(results: [AudioQualityProviderResult]) {
        self.results = results
    }

    func currentQuality(for mediaInfo: MediaInfo) async -> AudioQualityProviderResult {
        guard !results.isEmpty else { return .unavailable(.providerUnavailable) }
        return results.removeFirst()
    }
}

private actor PlaybackStateAudioQualityProvider: AudioQualityProvider {
    let identifier = "playback-state-harness"
    let quality: VerifiedAudioQuality

    init(quality: VerifiedAudioQuality) {
        self.quality = quality
    }

    func currentQuality(for mediaInfo: MediaInfo) async -> AudioQualityProviderResult {
        mediaInfo.playbackState == .playing
            ? .verified(quality)
            : .unavailable(.noCurrentMedia)
    }
}

@MainActor
private final class HarnessMediaProvider: MediaProvider {
    let identifier = "harness"
    var onMediaChanged: ((MediaInfo?) -> Void)?

    func currentMedia() async -> MediaInfo? { nil }
    func startMonitoring() {}
    func stopMonitoring() {}

    func publish(_ mediaInfo: MediaInfo?) {
        onMediaChanged?(mediaInfo)
    }
}
