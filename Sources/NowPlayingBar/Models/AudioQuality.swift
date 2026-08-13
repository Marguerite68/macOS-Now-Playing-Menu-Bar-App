import Foundation

enum AudioQualityTier: String, Hashable, Sendable {
    case lossless
    case hiResLossless

    var displayName: String {
        switch self {
        case .lossless: "无损"
        case .hiResLossless: "高解析无损"
        }
    }

    var badgeText: String {
        switch self {
        case .lossless: "LOSSLESS"
        case .hiResLossless: "HI-RES"
        }
    }

    var badgeWidth: CGFloat {
        switch self {
        case .lossless: 47
        case .hiResLossless: 45
        }
    }

    var appleMusicAssetName: String {
        switch self {
        case .lossless: "audioBadgeLosslessTemplate"
        case .hiResLossless: "audioBadgeHi-ResLosslessTemplate"
        }
    }
}

struct VerifiedAudioQuality: Equatable, Sendable {
    let tier: AudioQualityTier
    let sampleRate: Int?
    let bitDepth: Int?
    let bitRate: Int?
    let evidenceDescription: String
    let providerIdentifier: String
}

enum AudioQualityUnavailableReason: Equatable, Sendable {
    case accessibilityPermissionRequired
    case noCurrentMedia
    case unsupportedSource
    case noPlaybackEvidence
    case providerUnavailable

    var explanation: String {
        switch self {
        case .accessibilityPermissionRequired:
            "NowPlayingBar 需要“辅助功能”权限，才能只读检查 Music 当前播放控件中的音质标识。"
        case .noCurrentMedia:
            "当前没有正在播放、可用于识别音质的 Apple Music 曲目。"
        case .unsupportedSource:
            "当前媒体来源暂未提供音质识别。首版仅支持 Apple Music。"
        case .noPlaybackEvidence:
            "Music 当前播放控件没有提供可验证的无损标识。可能是普通音质，也可能是当前版本的 Music 未向辅助功能公开该信息。"
        case .providerUnavailable:
            "暂时无法读取 Music 的播放控件。NowPlayingBar 会尝试维持一个最小化的 Music 窗口用于后台识别；若仍失败，可重新打开 Music 后再试。"
        }
    }
}

enum AudioQualityDetailsState: Equatable, Sendable {
    case hidden
    case verified(VerifiedAudioQuality)
    case unavailable(AudioQualityUnavailableReason)

    init(
        recognitionEnabled: Bool,
        quality: VerifiedAudioQuality?,
        unavailableReason: AudioQualityUnavailableReason
    ) {
        guard recognitionEnabled else {
            self = .hidden
            return
        }
        if let quality {
            self = .verified(quality)
        } else {
            self = .unavailable(unavailableReason)
        }
    }
}
