import SwiftUI

@main
@MainActor
struct NowPlayingBarApp: App {
    @StateObject private var manager: NowPlayingManager
    @StateObject private var settings: AppSettings
    @StateObject private var statusBarController: StatusBarController

    init() {
        let settings = AppSettings()
        let manager = NowPlayingManager(provider: SystemNowPlayingProvider())

        _settings = StateObject(wrappedValue: settings)
        _manager = StateObject(wrappedValue: manager)
        _statusBarController = StateObject(
            wrappedValue: StatusBarController(manager: manager, settings: settings)
        )
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
