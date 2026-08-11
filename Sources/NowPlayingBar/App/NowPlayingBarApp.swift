import SwiftUI

@main
@MainActor
struct NowPlayingBarApp: App {
    @StateObject private var manager = NowPlayingManager(provider: SystemNowPlayingProvider())
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        MenuBarExtra {
            NowPlayingPopover(manager: manager, settings: settings)
        } label: {
            MenuBarLabel(
                mediaInfo: manager.mediaInfo,
                scrollResetID: manager.scrollResetID,
                settings: settings
            )
        }
        .menuBarExtraStyle(.window)

        Window("NowPlayingBar 偏好设置", id: "preferences") {
            PreferencesView(
                settings: settings,
                mediaInfo: manager.mediaInfo
            )
        }
        .defaultSize(width: 540, height: 360)
        .windowResizability(.contentSize)
    }
}
