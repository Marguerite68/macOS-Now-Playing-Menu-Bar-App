import Foundation

protocol AudioQualityProvider: Sendable {
    var identifier: String { get }

    func currentQuality(for mediaInfo: MediaInfo) async -> AudioQualityProviderResult
    func stopMonitoring() async
}

extension AudioQualityProvider {
    func stopMonitoring() async {}
}

enum AudioQualityProviderResult: Equatable, Sendable {
    case verified(VerifiedAudioQuality)
    case unavailable(AudioQualityUnavailableReason)
}
