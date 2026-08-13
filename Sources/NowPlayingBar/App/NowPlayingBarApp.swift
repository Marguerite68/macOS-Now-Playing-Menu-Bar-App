import SwiftUI

@main
@MainActor
struct NowPlayingBarApp: App {
    @StateObject private var manager: NowPlayingManager
    @StateObject private var settings: AppSettings
    @StateObject private var audioQualityManager: AudioQualityManager
    @StateObject private var statusBarController: StatusBarController

    init() {
        let settings = AppSettings()
        let manager = NowPlayingManager(provider: SystemNowPlayingProvider())
        let audioQualityManager = AudioQualityManager(
            mediaManager: manager,
            settings: settings,
            provider: AppleMusicAccessibilityQualityProvider()
        )

        _settings = StateObject(wrappedValue: settings)
        _manager = StateObject(wrappedValue: manager)
        _audioQualityManager = StateObject(wrappedValue: audioQualityManager)
        _statusBarController = StateObject(
            wrappedValue: StatusBarController(
                manager: manager,
                settings: settings,
                audioQualityManager: audioQualityManager
            )
        )
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
