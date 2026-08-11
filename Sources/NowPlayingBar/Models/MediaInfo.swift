import Foundation

enum MediaApplication: String, Sendable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case safari = "Safari"
    case other = "Other"
    case unknown = "Unknown"
}

enum PlaybackState: String, Sendable {
    case playing
    case paused
    case stopped
    case unknown

    var displayName: String {
        switch self {
        case .playing: "播放中"
        case .paused: "已暂停"
        case .stopped: "已停止"
        case .unknown: "未知"
        }
    }
}

struct MediaInfo: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let artist: String?
    let album: String?
    let application: MediaApplication
    let playbackState: PlaybackState

    var menuBarText: String {
        guard let artist, !artist.isEmpty else { return title }
        return "\(title) · \(artist)"
    }

    func replacingPlaybackState(with state: PlaybackState) -> MediaInfo {
        MediaInfo(
            id: id,
            title: title,
            artist: artist,
            album: album,
            application: application,
            playbackState: state
        )
    }
}
