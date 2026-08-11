import AppKit
import Combine

struct StatusBarPresentation {
    let title: String
    let iconName: String
    let accessibilityLabel: String
    let statusItemLength: CGFloat

    init(
        mediaInfo: MediaInfo?,
        displayMode: MenuBarDisplayMode,
        iconOnlyWhenNoMedia: Bool
    ) {
        title = displayMode.text(
            for: mediaInfo,
            iconOnlyWhenNoMedia: iconOnlyWhenNoMedia
        ) ?? ""

        switch mediaInfo?.playbackState {
        case .paused:
            iconName = "pause.fill"
        case .stopped:
            iconName = "stop.fill"
        default:
            iconName = "music.note"
        }

        accessibilityLabel = title.isEmpty ? "NowPlayingBar" : "NowPlayingBar: \(title)"
        let textWidth = title.isEmpty ? 0 : MarqueeMetrics.menuBar(text: title).viewportWidth
        statusItemLength = title.isEmpty ? 24 : min(textWidth + 25, 255)
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
        cancellable = Publishers.CombineLatest3(
            manager.$mediaInfo,
            settings.$displayMode,
            settings.$iconOnlyWhenNoMedia
        )
        .map { mediaInfo, displayMode, iconOnlyWhenNoMedia in
            StatusBarPresentation(
                mediaInfo: mediaInfo,
                displayMode: displayMode,
                iconOnlyWhenNoMedia: iconOnlyWhenNoMedia
            )
        }
        .sink(receiveValue: onChange)
    }
}
