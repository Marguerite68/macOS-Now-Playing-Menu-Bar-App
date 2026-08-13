import AppKit
import SwiftUI

struct NowPlayingDetailsView: View {
    @ObservedObject var manager: NowPlayingManager
    @ObservedObject var settings: AppSettings
    @ObservedObject var audioQualityManager: AudioQualityManager
    @State private var showsQualityExplanation = false

    private var qualityState: AudioQualityDetailsState {
        AudioQualityDetailsState(
            recognitionEnabled: settings.audioQualityRecognitionEnabled,
            quality: audioQualityManager.quality,
            unavailableReason: audioQualityManager.unavailableReason
        )
    }

    private var panelWidth: CGFloat {
        DetailsPanelLayout.width(
            for: manager.mediaInfo,
            recognitionEnabled: settings.audioQualityRecognitionEnabled
        )
    }

    var body: some View {
        Group {
            if let mediaInfo = manager.mediaInfo {
                HStack(alignment: .center, spacing: 16) {
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

                        switch qualityState {
                        case .hidden:
                            EmptyView()
                        case .verified(let quality):
                            verifiedQualityDetails(quality)
                        case .unavailable(let reason):
                            unavailableQualityDetails(reason)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    AlbumArtworkView(
                        mediaInfo: mediaInfo,
                        size: DetailsPanelLayout.artworkSize(
                            recognitionEnabled: settings.audioQualityRecognitionEnabled
                        )
                    )
                }
            } else {
                Text("当前没有可读取的媒体")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(
            DetailsPanelLayout.padding(
                recognitionEnabled: settings.audioQualityRecognitionEnabled
            )
        )
        .frame(
            width: panelWidth,
            height: DetailsPanelLayout.height(
                recognitionEnabled: settings.audioQualityRecognitionEnabled
            ),
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func verifiedQualityDetails(_ quality: VerifiedAudioQuality) -> some View {
        HStack(spacing: 6) {
            QualityBadgeView(tier: quality.tier)
            Text(qualitySummary(quality))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func unavailableQualityDetails(
        _ reason: AudioQualityUnavailableReason
    ) -> some View {
        HStack(spacing: 6) {
            Text(reason == .noPlaybackEvidence ? "高质量" : "未获得音质信息")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                showsQualityExplanation.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("为什么没有音质信息")
            .popover(isPresented: $showsQualityExplanation, arrowEdge: .bottom) {
                QualityExplanationView(reason: reason)
            }
        }
    }

    private func qualitySummary(_ quality: VerifiedAudioQuality) -> String {
        var components: [String] = []
        if let bitDepth = quality.bitDepth {
            components.append("\(bitDepth)-bit")
        }
        if let sampleRate = quality.sampleRate {
            let value = Self.sampleRateFormatter.string(
                from: NSNumber(value: Double(sampleRate) / 1_000)
            ) ?? "\(Double(sampleRate) / 1_000)"
            components.append("\(value) kHz")
        }
        if let bitRate = quality.bitRate {
            components.append("\(bitRate) kbps")
        }
        return components.isEmpty ? quality.tier.displayName : components.joined(separator: " · ")
    }

    private static let sampleRateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

struct QualityBadgeView: View {
    let tier: AudioQualityTier

    var body: some View {
        Group {
            if let image = AudioQualityBadgeAsset.image(for: tier) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: tier.badgeWidth, height: 14)
                    .foregroundStyle(.primary)
            } else {
                Text(tier.badgeText)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(.secondary, lineWidth: 1)
                    }
            }
        }
        .accessibilityLabel(tier.displayName)
    }
}

private struct QualityExplanationView: View {
    let reason: AudioQualityUnavailableReason

    private var title: String {
        reason == .noPlaybackEvidence ? "关于“高质量”" : "为什么没有音质信息？"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(reason.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if reason == .accessibilityPermissionRequired {
                Button("打开系统设置") {
                    AccessibilitySettingsOpener.open()
                }
            }
        }
        .padding(14)
        .frame(width: 280, alignment: .leading)
    }
}

enum AccessibilitySettingsOpener {
    @MainActor
    static func open() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
