import AppKit
import Combine

struct StatusBarPresentation {
    let title: String
    let fullText: String
    let iconName: String
    let accessibilityLabel: String
    let statusItemLength: CGFloat
    let textViewportWidth: CGFloat
    let shouldScroll: Bool
    let isPlaying: Bool
    let trackID: String
    let marqueeMode: MarqueeMode
    let scrollingSpeed: CGFloat
    let fontWeight: MenuBarFontWeight

    init(
        mediaInfo: MediaInfo?,
        displayMode: MenuBarDisplayMode,
        iconOnlyWhenNoMedia: Bool,
        maximumCharacters: Int = 20,
        scrollingEnabled: Bool = true,
        marqueeMode: MarqueeMode = .loop,
        scrollingSpeed: Double = 28,
        fontWeight: MenuBarFontWeight = .medium
    ) {
        fullText = displayMode.text(
            for: mediaInfo,
            iconOnlyWhenNoMedia: iconOnlyWhenNoMedia
        ) ?? ""
        title = MenuBarTextLimiter.displayedText(
            fullText,
            maximumCharacters: maximumCharacters,
            scrollingEnabled: scrollingEnabled
        )
        let hasOverflow = fullText.count > maximumCharacters
        shouldScroll = scrollingEnabled && hasOverflow
        isPlaying = mediaInfo?.playbackState == .playing
        trackID = mediaInfo?.id ?? "no-media"
        self.marqueeMode = marqueeMode
        self.scrollingSpeed = CGFloat(scrollingSpeed)
        self.fontWeight = fontWeight

        switch mediaInfo?.playbackState {
        case .paused:
            iconName = "pause.fill"
        case .stopped:
            iconName = "stop.fill"
        default:
            iconName = "music.note"
        }

        accessibilityLabel = fullText.isEmpty ? "NowPlayingBar" : "NowPlayingBar: \(fullText)"

        if title.isEmpty {
            textViewportWidth = 0
            statusItemLength = 24
        } else {
            if shouldScroll {
                textViewportWidth = MarqueeMetrics.menuBar(
                    text: fullText,
                    maximumCharacters: maximumCharacters,
                    fontWeight: fontWeight
                ).viewportWidth
            } else {
                textViewportWidth = min(
                    TextMeasurer.width(
                        of: title,
                        font: .systemFont(
                            ofSize: MenuBarLayout.fontSize,
                            weight: fontWeight.nsWeight
                        )
                    ),
                    MenuBarLayout.maximumTextWidth
                )
            }
            statusItemLength = MenuBarLayout.horizontalPadding
                + MenuBarLayout.iconWidth
                + MenuBarLayout.iconTextSpacing
                + textViewportWidth
                + MenuBarLayout.horizontalPadding
        }
    }
}

@MainActor
final class StatusBarPresentationObserver {
    private var cancellable: AnyCancellable?

    init(
        manager: NowPlayingManager,
        settings: AppSettings,
        onChange: @escaping (StatusBarPresentation) -> Void
    ) {
        let displaySettings = Publishers.CombineLatest4(
            settings.$displayMode,
            settings.$iconOnlyWhenNoMedia,
            settings.$maximumCharacters,
            settings.$scrollingEnabled
        )
        let animationSettings = Publishers.CombineLatest3(
            settings.$marqueeMode,
            settings.$scrollingSpeed,
            settings.$fontWeight
        )

        cancellable = Publishers.CombineLatest3(
            manager.$mediaInfo,
            displaySettings,
            animationSettings
        )
        .map { mediaInfo, displaySettings, animationSettings in
            StatusBarPresentation(
                mediaInfo: mediaInfo,
                displayMode: displaySettings.0,
                iconOnlyWhenNoMedia: displaySettings.1,
                maximumCharacters: displaySettings.2,
                scrollingEnabled: displaySettings.3,
                marqueeMode: animationSettings.0,
                scrollingSpeed: animationSettings.1,
                fontWeight: animationSettings.2
            )
        }
        .sink(receiveValue: onChange)
    }
}
