import AppKit

enum DetailsPanelLayout {
    static let maximumWidth: CGFloat = 390
    static let metadataArtworkSpacing: CGFloat = 16
    private static let minimumTextWidth: CGFloat = 130

    static func contentSize(
        for mediaInfo: MediaInfo?,
        recognitionEnabled: Bool
    ) -> NSSize {
        NSSize(
            width: width(for: mediaInfo, recognitionEnabled: recognitionEnabled),
            height: height(recognitionEnabled: recognitionEnabled)
        )
    }

    static func width(
        for mediaInfo: MediaInfo?,
        recognitionEnabled: Bool
    ) -> CGFloat {
        let padding = padding(recognitionEnabled: recognitionEnabled)
        let artworkWidth = artworkSize(recognitionEnabled: recognitionEnabled)
        let maximumTextWidth = maximumWidth
            - padding * 2
            - artworkWidth
            - metadataArtworkSpacing
        let preferredTextWidth = min(
            max(metadataWidth(for: mediaInfo, recognitionEnabled: recognitionEnabled), minimumTextWidth),
            maximumTextWidth
        )

        return ceil(
            padding * 2
                + preferredTextWidth
                + metadataArtworkSpacing
                + artworkWidth
        )
    }

    static func height(recognitionEnabled: Bool) -> CGFloat {
        recognitionEnabled ? 140 : 116
    }

    static func artworkSize(recognitionEnabled: Bool) -> CGFloat {
        recognitionEnabled ? 112 : 84
    }

    static func padding(recognitionEnabled: Bool) -> CGFloat {
        recognitionEnabled ? 14 : 16
    }

    private static func metadataWidth(
        for mediaInfo: MediaInfo?,
        recognitionEnabled: Bool
    ) -> CGFloat {
        guard let mediaInfo else { return minimumTextWidth }

        let titleFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let bodyFont = NSFont.systemFont(ofSize: 13)
        let captionFont = NSFont.systemFont(ofSize: 11)
        let metadata = [
            (mediaInfo.title, titleFont),
            (mediaInfo.artist ?? "未知艺术家", bodyFont),
            (mediaInfo.album ?? "", captionFont),
            ("\(mediaInfo.application.rawValue) · \(mediaInfo.playbackState.displayName)", captionFont),
            (recognitionEnabled ? "未获得音质信息" : "", captionFont)
        ]

        return metadata.map { text, font in
            ceil((text as NSString).size(withAttributes: [.font: font]).width)
        }
        .max() ?? minimumTextWidth
    }
}
