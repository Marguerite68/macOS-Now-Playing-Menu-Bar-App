import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    let mediaInfo: MediaInfo?

    var body: some View {
        TabView {
            DisplayPreferencesView(settings: settings, mediaInfo: mediaInfo)
                .tabItem {
                    Label("显示", systemImage: "menubar.rectangle")
                }

            AboutPreferencesView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .padding(20)
        .frame(width: 540, height: 360)
    }
}

private struct DisplayPreferencesView: View {
    @ObservedObject var settings: AppSettings
    let mediaInfo: MediaInfo?

    private var previewText: String {
        settings.displayMode.text(
            for: mediaInfo ?? Self.previewMedia,
            iconOnlyWhenNoMedia: settings.iconOnlyWhenNoMedia
        ) ?? ""
    }

    var body: some View {
        Form {
            Section("菜单栏显示") {
                Picker("显示内容", selection: $settings.displayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                            Text(mode.example)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Toggle(
                    "未读取到媒体时仅显示图标",
                    isOn: $settings.iconOnlyWhenNoMedia
                )
            }

            Section("当前预览") {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                    if !previewText.isEmpty {
                        Text(previewText)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))

                Text("设置会立即应用到菜单栏，并在应用重启后保留。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if mediaInfo == nil {
                    Label(
                        "当前未读取到 Music 或 Spotify。请确认播放器正在运行，并允许 NowPlayingBar 使用“自动化”权限。",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    private static let previewMedia = MediaInfo(
        id: "settings-preview",
        title: "Blinding Lights",
        artist: "The Weeknd",
        album: "After Hours",
        application: .appleMusic,
        playbackState: .playing
    )
}

private struct AboutPreferencesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("NowPlayingBar")
                .font(.title2.weight(.semibold))
            Text("Version 0.1.0")
                .foregroundStyle(.secondary)
            Text("原生、轻量的 macOS 菜单栏媒体信息工具")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
