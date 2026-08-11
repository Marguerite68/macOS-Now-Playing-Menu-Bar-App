import SwiftUI

struct NowPlayingDetailsView: View {
    @ObservedObject var manager: NowPlayingManager

    var body: some View {
        Group {
            if let mediaInfo = manager.mediaInfo {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mediaInfo.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(mediaInfo.artist ?? "未知艺术家")
                        .foregroundStyle(.secondary)
                    if let album = mediaInfo.album, !album.isEmpty {
                        Text(album)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(mediaInfo.application.rawValue) · \(mediaInfo.playbackState.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("当前没有可读取的媒体")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }
}
