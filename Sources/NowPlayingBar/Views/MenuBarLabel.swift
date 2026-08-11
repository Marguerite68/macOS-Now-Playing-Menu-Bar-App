import SwiftUI

struct MenuBarLabel: View {
    let mediaInfo: MediaInfo?
    let scrollResetID: UUID
    @ObservedObject var settings: AppSettings

    private var displayText: String? {
        settings.displayMode.text(
            for: mediaInfo,
            iconOnlyWhenNoMedia: settings.iconOnlyWhenNoMedia
        )
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .imageScale(.small)

            if let displayText {
                let metrics = MarqueeMetrics.menuBar(text: displayText)
                // MenuBarExtra reliably hosts native SwiftUI text, while an NSViewRepresentable
                // can be measured but omitted from the rendered status-item label.
                Text(displayText)
                    .font(.system(size: MenuBarLayout.fontSize, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                .frame(width: metrics.viewportWidth, height: 18)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch mediaInfo?.playbackState {
        case .paused:
            "pause.fill"
        case .stopped:
            "stop.fill"
        default:
            "music.note"
        }
    }
}
