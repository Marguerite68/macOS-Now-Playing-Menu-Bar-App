import AppKit
import SwiftUI

struct AlbumArtworkView: View {
    let mediaInfo: MediaInfo

    var body: some View {
        Group {
            if let artworkURL = mediaInfo.artworkURL, artworkURL.isFileURL,
               let artworkImage = NSImage(contentsOf: artworkURL) {
                Image(nsImage: artworkImage)
                    .resizable()
                    .scaledToFill()
            } else if let artworkURL = mediaInfo.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .id(mediaInfo.id)
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .accessibilityLabel("\(mediaInfo.title) 的歌曲封面")
    }

    private var artworkPlaceholder: some View {
        ZStack {
            Color(nsColor: .darkGray)
            Image(systemName: "music.note")
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(Color(nsColor: .lightGray))
        }
    }
}
