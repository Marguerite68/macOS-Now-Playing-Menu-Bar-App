import SwiftUI

struct MenuBarLabel: View {
    let mediaInfo: MediaInfo?
    let scrollResetID: UUID

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .imageScale(.small)

            ScrollingTextView(
                text: mediaInfo?.menuBarText ?? "—",
                isPlaying: mediaInfo?.playbackState == .playing,
                resetID: scrollResetID
            )
        }
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
