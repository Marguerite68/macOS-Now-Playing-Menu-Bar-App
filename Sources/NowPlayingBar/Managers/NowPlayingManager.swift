import Foundation

@MainActor
final class NowPlayingManager: ObservableObject {
    @Published private(set) var mediaInfo: MediaInfo?
    @Published private(set) var scrollResetID = UUID()

    private let provider: any MediaProvider

    init(provider: any MediaProvider) {
        self.provider = provider
        provider.onMediaChanged = { [weak self] mediaInfo in
            self?.receive(mediaInfo)
        }
        provider.startMonitoring()
    }

    func refresh() async {
        receive(await provider.currentMedia())
    }

    func resetScrolling() {
        scrollResetID = UUID()
    }

    private func receive(_ newMediaInfo: MediaInfo?) {
        guard mediaInfo != newMediaInfo else { return }

        let didChangeTrack = mediaInfo?.id != newMediaInfo?.id
            || mediaInfo?.menuBarText != newMediaInfo?.menuBarText
        mediaInfo = newMediaInfo

        if didChangeTrack {
            scrollResetID = UUID()
        }
    }
}
