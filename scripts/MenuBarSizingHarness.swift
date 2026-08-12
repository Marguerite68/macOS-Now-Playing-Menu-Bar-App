import Darwin
import Foundation

@main
@MainActor
struct MenuBarSizingHarness {
    static func main() {
        let text = "Blinding Lights · The Weeknd"
        let metrics = MarqueeMetrics.menuBar(text: text)
        guard metrics.textWidth > 0,
              metrics.viewportWidth > 0,
              metrics.viewportWidth <= MenuBarLayout.maximumTextWidth else {
            fputs("FAIL: menu-bar text metrics are invalid\n", stderr)
            exit(1)
        }

        let mediaInfo = MediaInfo(
            id: "display-mode-test",
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            application: .appleMusic,
            playbackState: .playing
        )

        guard MenuBarDisplayMode.iconOnly.text(
            for: mediaInfo,
            iconOnlyWhenNoMedia: true
        ) == nil else {
            fputs("FAIL: icon-only mode emitted text\n", stderr)
            exit(1)
        }

        guard MenuBarDisplayMode.title.text(
            for: mediaInfo,
            iconOnlyWhenNoMedia: true
        ) == "Blinding Lights" else {
            fputs("FAIL: title mode did not emit the title\n", stderr)
            exit(1)
        }

        guard MenuBarDisplayMode.titleAndArtist.text(
            for: mediaInfo,
            iconOnlyWhenNoMedia: true
        ) == "Blinding Lights · The Weeknd" else {
            fputs("FAIL: title-and-artist mode emitted the wrong text\n", stderr)
            exit(1)
        }

        guard MenuBarDisplayMode.title.text(
            for: nil,
            iconOnlyWhenNoMedia: true
        ) == nil else {
            fputs("FAIL: no-media icon-only policy emitted text\n", stderr)
            exit(1)
        }

        let presentation = StatusBarPresentation(
            mediaInfo: mediaInfo,
            displayMode: .titleAndArtist,
            iconOnlyWhenNoMedia: false
        )
        guard presentation.title == "Blinding Lights · The Weeknd",
              presentation.shouldScroll,
              presentation.statusItemLength > 100 else {
            fputs("FAIL: status-item presentation omitted the title\n", stderr)
            exit(1)
        }

        let truncatedPresentation = StatusBarPresentation(
            mediaInfo: mediaInfo,
            displayMode: .titleAndArtist,
            iconOnlyWhenNoMedia: false,
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
            iconOnlyWhenNoMedia: false
        )
        var observedPresentation: StatusBarPresentation?
        let observer = StatusBarPresentationObserver(
            manager: manager,
            settings: settings
        ) { observedPresentation = $0 }

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
