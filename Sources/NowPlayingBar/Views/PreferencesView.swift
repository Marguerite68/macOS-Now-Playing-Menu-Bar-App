import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var manager: NowPlayingManager

    var body: some View {
        TabView {
            DisplayPreferencesView(settings: settings, mediaInfo: manager.mediaInfo)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .tabItem {
                    Label("显示", systemImage: "menubar.rectangle")
                }

            AboutPreferencesView()
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 540, height: 500)
    }
}

private struct DisplayPreferencesView: View {
    @ObservedObject var settings: AppSettings
    let mediaInfo: MediaInfo?
    @State private var maximumCharactersInput: String
    @FocusState private var isMaximumCharactersFieldFocused: Bool

    init(settings: AppSettings, mediaInfo: MediaInfo?) {
        _settings = ObservedObject(wrappedValue: settings)
        self.mediaInfo = mediaInfo
        _maximumCharactersInput = State(initialValue: String(settings.maximumCharacters))
    }

    private var previewPresentation: StatusBarPresentation {
        let previewMedia = (mediaInfo ?? Self.previewMedia)
            .replacingPlaybackState(with: .playing)
        return StatusBarPresentation(
            mediaInfo: previewMedia,
            displayMode: settings.displayMode,
            iconOnlyWhenNoMedia: settings.iconOnlyWhenNoMedia,
            maximumCharacters: settings.maximumCharacters,
            scrollingEnabled: settings.scrollingEnabled,
            marqueeMode: settings.marqueeMode,
            scrollingSpeed: settings.scrollingSpeed,
            fontWeight: settings.fontWeight
        )
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

                Picker("字体粗细", selection: $settings.fontWeight) {
                    ForEach(MenuBarFontWeight.allCases) { weight in
                        Text(weight.displayName).tag(weight)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("滚动显示") {
                HStack(spacing: 8) {
                    Text("显示字符数限制")
                    Spacer(minLength: 16)

                    Button {
                        adjustMaximumCharacters(by: -MarqueeSettingRange.characterStep)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(settings.maximumCharacters <= MarqueeSettingRange.minimumCharacters)

                    TextField("", text: $maximumCharactersInput)
                        .labelsHidden()
                        .frame(width: 42)
                        .multilineTextAlignment(.center)
                        .focused($isMaximumCharactersFieldFocused)
                        .onSubmit(commitMaximumCharactersInput)
                        .onChange(of: maximumCharactersInput) { newValue in
                            applyValidMaximumCharacters(newValue)
                        }

                    Button {
                        adjustMaximumCharacters(by: MarqueeSettingRange.characterStep)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(settings.maximumCharacters >= MarqueeSettingRange.maximumCharacters)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text(
                    "可设置范围：\(MarqueeSettingRange.minimumCharacters)–\(MarqueeSettingRange.maximumCharacters) 个字符"
                )
                .font(.caption)
                .foregroundColor(isMaximumCharactersInputValid ? .secondary : .red)

                Toggle("超过显示字符数限制时自动滚动", isOn: $settings.scrollingEnabled)

                if settings.scrollingEnabled {
                    Picker("滚动模式", selection: $settings.marqueeMode) {
                        ForEach(MarqueeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("滚动速度") {
                        HStack(spacing: 6) {
                            Image(systemName: "tortoise.fill")
                                .foregroundStyle(.secondary)
                            Slider(
                                value: $settings.scrollingSpeed,
                                in: MarqueeSettingRange.minimumSpeed...MarqueeSettingRange.maximumSpeed,
                                step: MarqueeSettingRange.speedStep
                            )
                            Image(systemName: "hare.fill")
                                .foregroundStyle(.secondary)
                            Text("\(Int(settings.scrollingSpeed)) pt/s")
                                .monospacedDigit()
                                .frame(width: 58, alignment: .trailing)
                        }
                    }
                }
            }

            Section("效果预览") {
                HStack(spacing: 6) {
                    Image(systemName: previewPresentation.iconName)
                    if !previewPresentation.title.isEmpty {
                        MarqueeTextPreview(presentation: previewPresentation)
                            .frame(
                                width: previewPresentation.textViewportWidth,
                                height: 18
                            )
                    }
                }
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))

                Text("设置会立即应用到菜单栏")
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
        .onChange(of: isMaximumCharactersFieldFocused) { isFocused in
            if !isFocused {
                commitMaximumCharactersInput()
            }
        }
        .onChange(of: settings.maximumCharacters) { newValue in
            if !isMaximumCharactersFieldFocused {
                maximumCharactersInput = String(newValue)
            }
        }
    }

    private var isMaximumCharactersInputValid: Bool {
        guard let value = Int(maximumCharactersInput) else { return false }
        return (MarqueeSettingRange.minimumCharacters...MarqueeSettingRange.maximumCharacters)
            .contains(value)
    }

    private func applyValidMaximumCharacters(_ input: String) {
        guard let value = Int(input),
              (MarqueeSettingRange.minimumCharacters...MarqueeSettingRange.maximumCharacters)
                .contains(value) else { return }
        settings.maximumCharacters = value
    }

    private func commitMaximumCharactersInput() {
        let enteredValue = Int(maximumCharactersInput) ?? settings.maximumCharacters
        let clampedValue = min(
            max(enteredValue, MarqueeSettingRange.minimumCharacters),
            MarqueeSettingRange.maximumCharacters
        )
        settings.maximumCharacters = clampedValue
        maximumCharactersInput = String(clampedValue)
    }

    private func adjustMaximumCharacters(by delta: Int) {
        let newValue = min(
            max(
                settings.maximumCharacters + delta,
                MarqueeSettingRange.minimumCharacters
            ),
            MarqueeSettingRange.maximumCharacters
        )
        settings.maximumCharacters = newValue
        maximumCharactersInput = String(newValue)
    }

    private static let previewMedia = MediaInfo(
        id: "settings-preview",
        title: "Blinding Lights (Live From NowPlayingBar)",
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
