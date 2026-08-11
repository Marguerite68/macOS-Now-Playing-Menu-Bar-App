import AppKit
import Darwin
import Foundation
import SwiftUI

@main
@MainActor
struct MenuBarSizingHarness {
    static func main() {
        let text = "Blinding Lights · The Weeknd"
        let metrics = MarqueeMetrics.menuBar(text: text)
        let view = MarqueeContainerView(frame: .zero)
        view.update(
            text: text,
            metrics: metrics,
            isPlaying: true,
            resetID: UUID()
        )

        let size = view.intrinsicContentSize
        guard size.width > 0, size.height > 0 else {
            fputs("FAIL: marquee intrinsic size is \(size.width) x \(size.height)\n", stderr)
            exit(1)
        }

        guard abs(size.width - metrics.viewportWidth) < 0.5 else {
            fputs("FAIL: intrinsic width \(size.width) does not match viewport \(metrics.viewportWidth)\n", stderr)
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

        let settings = AppSettings(
            transientDisplayMode: .titleAndArtist,
            iconOnlyWhenNoMedia: false
        )

        let label = MenuBarLabel(
            mediaInfo: mediaInfo,
            scrollResetID: UUID(),
            settings: settings
        )
        let hostedLabel = NSHostingView(rootView: label)
        let hostedSize = hostedLabel.fittingSize
        guard hostedSize.width > 100 else {
            fputs("FAIL: menu-bar label is only \(hostedSize.width) points wide\n", stderr)
            exit(1)
        }

        print("PASS: marquee size, display modes, and menu-bar text layout are valid")
    }
}
