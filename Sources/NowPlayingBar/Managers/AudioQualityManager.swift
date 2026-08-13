import ApplicationServices
import Combine
import Foundation

@MainActor
final class AudioQualityManager: ObservableObject {
    @Published private(set) var quality: VerifiedAudioQuality?
    @Published private(set) var unavailableReason: AudioQualityUnavailableReason = .noCurrentMedia

    private let provider: any AudioQualityProvider
    private let isAccessibilityTrusted: () -> Bool
    private let settings: AppSettings
    private weak var mediaManager: NowPlayingManager?
    private var monitoringTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var verifiedMediaID: String?

    init(
        mediaManager: NowPlayingManager,
        settings: AppSettings,
        provider: any AudioQualityProvider,
        isAccessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() }
    ) {
        self.mediaManager = mediaManager
        self.settings = settings
        self.provider = provider
        self.isAccessibilityTrusted = isAccessibilityTrusted

        settings.$audioQualityRecognitionEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.recognitionSettingChanged(enabled)
            }
            .store(in: &cancellables)

        mediaManager.$mediaInfo
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] mediaInfo in
                guard let self else { return }
                if self.verifiedMediaID != mediaInfo?.id {
                    self.quality = nil
                    self.verifiedMediaID = nil
                }
                if self.settings.audioQualityRecognitionEnabled {
                    Task { await self.refresh() }
                }
            }
            .store(in: &cancellables)
    }

    func setRecognitionEnabled(_ enabled: Bool, promptForPermission: Bool) {
        settings.audioQualityRecognitionEnabled = enabled
        if enabled,
           promptForPermission,
           !settings.didRequestAudioQualityAccessibility,
           !isAccessibilityTrusted() {
            settings.didRequestAudioQualityAccessibility = true
            let options = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        if enabled {
            Task { await refresh() }
        }
    }

    func refresh() async {
        guard settings.audioQualityRecognitionEnabled else {
            quality = nil
            verifiedMediaID = nil
            return
        }
        guard isAccessibilityTrusted() else {
            publish(.unavailable(.accessibilityPermissionRequired))
            return
        }
        guard let mediaInfo = mediaManager?.mediaInfo else {
            publish(.unavailable(.noCurrentMedia))
            return
        }
        let result = await provider.currentQuality(for: mediaInfo)
        guard mediaManager?.mediaInfo == mediaInfo,
              settings.audioQualityRecognitionEnabled else {
            return
        }
        publish(result)
    }

    private func recognitionSettingChanged(_ enabled: Bool) {
        monitoringTask?.cancel()
        monitoringTask = nil

        guard enabled else {
            quality = nil
            verifiedMediaID = nil
            unavailableReason = .noCurrentMedia
            Task { await provider.stopMonitoring() }
            return
        }

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
    }

    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        await provider.stopMonitoring()
    }

    private func publish(_ result: AudioQualityProviderResult) {
        switch result {
        case .verified(let quality):
            self.quality = quality
            verifiedMediaID = mediaManager?.mediaInfo?.id
        case .unavailable(let reason):
            let canReuseVerifiedQuality = quality != nil
                && verifiedMediaID == mediaManager?.mediaInfo?.id
                && (reason == .providerUnavailable || reason == .noCurrentMedia)
            if canReuseVerifiedQuality {
                unavailableReason = reason
                return
            }
            quality = nil
            verifiedMediaID = nil
            unavailableReason = reason
        }
    }
}
