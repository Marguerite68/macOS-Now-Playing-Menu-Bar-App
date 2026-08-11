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
              presentation.statusItemLength > 100 else {
            fputs("FAIL: status-item presentation omitted the title\n", stderr)
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
