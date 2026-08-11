import AppKit
import SwiftUI

struct NowPlayingPopover: View {
    @ObservedObject var manager: NowPlayingManager

    private var metrics: MarqueeMetrics {
        .menuBar(text: manager.mediaInfo?.menuBarText ?? "—")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("NowPlayingBar")
                    .font(.headline)
                Text("实时读取 Music 与 Spotify")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Text(manager.mediaInfo?.title ?? "当前没有可读取的媒体")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(2)
                Text(manager.mediaInfo?.artist ?? "—")
                    .foregroundStyle(.secondary)
                Text(manager.mediaInfo?.album ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let mediaInfo = manager.mediaInfo {
                    Text("\(mediaInfo.application.rawValue) · \(mediaInfo.playbackState.displayName)")
                        .font(.caption)
                }
            }

            HStack {
                Button("立即刷新") {
                    Task { await manager.refresh() }
                }
                Button("重置滚动", action: manager.resetScrolling)
            }
            .buttonStyle(.bordered)

            GroupBox("滚动状态") {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                    GridRow {
                        Text("文本宽度")
                        Text("\(Int(metrics.textWidth)) px").monospacedDigit()
                    }
                    GridRow {
                        Text("可视宽度")
                        Text("\(Int(metrics.viewportWidth)) px").monospacedDigit()
                    }
                    GridRow {
                        Text("自动滚动")
                        Text(metrics.needsScrolling ? "是" : "否")
                    }
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
            }

            Text("首次读取播放器时，macOS 可能请求“自动化”权限。拒绝后应用会保持空闲，不会崩溃。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("退出 NowPlayingBar") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 350)
    }
}
