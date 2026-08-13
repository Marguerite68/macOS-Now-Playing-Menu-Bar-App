import AppKit
import Combine

struct StatusBarPresentation {
    let title: String
    let fullText: String
    let isHidden: Bool
    let iconName: String
    let qualityBadge: AudioQualityTier?
    let qualityBadgeWidth: CGFloat
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
        hideStatusItemWhenNoMedia: Bool = false,
        maximumCharacters: Int = 20,
        scrollingEnabled: Bool = true,
        marqueeMode: MarqueeMode = .loop,
        scrollingSpeed: Double = 28,
        fontWeight: MenuBarFontWeight = .medium,
        audioQuality: VerifiedAudioQuality? = nil
    ) {
        fullText = displayMode.text(for: mediaInfo) ?? ""
        isHidden = mediaInfo == nil && hideStatusItemWhenNoMedia
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
        qualityBadge = audioQuality?.tier
        qualityBadgeWidth = audioQuality?.tier.badgeWidth ?? 0

        if mediaInfo == nil {
            iconName = "zzz"
        } else {
            switch mediaInfo?.playbackState {
            case .paused:
                iconName = "pause.fill"
            case .stopped:
                iconName = "stop.fill"
            default:
                iconName = "music.note"
            }
        }

        let qualityAccessibilityText = audioQuality.map { ", \($0.tier.displayName)" } ?? ""
        accessibilityLabel = fullText.isEmpty
            ? "NowPlayingBar\(qualityAccessibilityText)"
            : "NowPlayingBar: \(fullText)\(qualityAccessibilityText)"

        if isHidden {
            textViewportWidth = 0
            statusItemLength = 0
        } else if title.isEmpty {
            textViewportWidth = 0
            statusItemLength = qualityBadge == nil
                ? 24
                : MenuBarLayout.horizontalPadding
                    + MenuBarLayout.iconWidth
                    + 5
                    + qualityBadgeWidth
                    + MenuBarLayout.horizontalPadding
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
                + (qualityBadge == nil ? 0 : 5 + qualityBadgeWidth)
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
        audioQualityManager: AudioQualityManager? = nil,
        onChange: @escaping (StatusBarPresentation) -> Void
    ) {
        let displaySettings = Publishers.CombineLatest4(
            settings.$displayMode,
            settings.$hideStatusItemWhenNoMedia,
            settings.$maximumCharacters,
            settings.$scrollingEnabled
        )
        let animationSettings = Publishers.CombineLatest3(
            settings.$marqueeMode,
            settings.$scrollingSpeed,
            settings.$fontWeight
        )

        let qualityPublisher = audioQualityManager?.$quality
            .eraseToAnyPublisher()
            ?? Just<VerifiedAudioQuality?>(nil).eraseToAnyPublisher()
        let playback = Publishers.CombineLatest(manager.$mediaInfo, qualityPublisher)

        cancellable = Publishers.CombineLatest3(
            playback,
            displaySettings,
            animationSettings
        )
        .map { playback, displaySettings, animationSettings in
            StatusBarPresentation(
                mediaInfo: playback.0,
                displayMode: displaySettings.0,
                hideStatusItemWhenNoMedia: displaySettings.1,
                maximumCharacters: displaySettings.2,
                scrollingEnabled: displaySettings.3,
                marqueeMode: animationSettings.0,
                scrollingSpeed: animationSettings.1,
                fontWeight: animationSettings.2,
                audioQuality: playback.1
            )
        }
        .sink(receiveValue: onChange)
    }
}
