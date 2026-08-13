import AppKit

@MainActor
enum AudioQualityBadgeAsset {
    private static let musicBundle = Bundle(path: "/System/Applications/Music.app")
    private static var cache: [AudioQualityTier: NSImage] = [:]

    static func image(for tier: AudioQualityTier) -> NSImage? {
        if let cached = cache[tier] {
            return cached
        }
        guard let source = musicBundle?.image(
            forResource: NSImage.Name(tier.appleMusicAssetName)
        ), let image = source.copy() as? NSImage else {
            return nil
        }
        image.isTemplate = true
        cache[tier] = image
        return image
    }
}

