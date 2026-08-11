import SwiftUI

@main
@MainActor
struct NowPlayingBarApp: App {
    @StateObject private var manager = NowPlayingManager(provider: SystemNowPlayingProvider())

    var body: some Scene {
        MenuBarExtra {
            NowPlayingPopover(manager: manager)
        } label: {
            MenuBarLabel(
                mediaInfo: manager.mediaInfo,
                scrollResetID: manager.scrollResetID
            )
        }
        .menuBarExtraStyle(.window)
    }
}
