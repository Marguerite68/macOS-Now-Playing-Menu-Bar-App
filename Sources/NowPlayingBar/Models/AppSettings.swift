import Foundation

enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case iconOnly
    case title
    case titleAndArtist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iconOnly:
            "仅图标"
        case .title:
            "图标 + 歌名"
        case .titleAndArtist:
            "图标 + 歌名 + 歌手"
        }
    }

    var example: String {
        switch self {
        case .iconOnly:
            "♫"
        case .title:
            "♫ Blinding Lights"
        case .titleAndArtist:
            "♫ Blinding Lights · The Weeknd"
        }
    }

    func text(for mediaInfo: MediaInfo?, iconOnlyWhenNoMedia: Bool) -> String? {
        guard self != .iconOnly else { return nil }
        guard let mediaInfo else { return iconOnlyWhenNoMedia ? nil : "—" }

        switch self {
        case .iconOnly:
            return nil
        case .title:
            return mediaInfo.title
        case .titleAndArtist:
            return mediaInfo.menuBarText
        }
    }
}

enum MarqueeMode: String, CaseIterable, Identifiable, Sendable {
    case loop
    case pingPong

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .loop: "循环"
        case .pingPong: "来回"
        }
    }
}

enum MenuBarFontWeight: String, CaseIterable, Identifiable, Sendable {
    case regular
    case medium
    case semibold
    case bold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .regular: "常规"
        case .medium: "中等"
        case .semibold: "半粗"
        case .bold: "粗体"
        }
    }
}

enum MarqueeSettingRange {
    static let minimumCharacters = 8
    static let maximumCharacters = 30
    static let characterStep = 1
    static let minimumSpeed = 12.0
    static let maximumSpeed = 60.0
    static let speedStep = 2.0
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let displayMode = "menuBarDisplayMode"
        static let iconOnlyWhenNoMedia = "iconOnlyWhenNoMedia"
        static let maximumCharacters = "maximumCharacters"
        static let scrollingEnabled = "scrollingEnabled"
        static let marqueeMode = "marqueeMode"
        static let scrollingSpeed = "scrollingSpeed"
        static let fontWeight = "fontWeight"
    }

    @Published var displayMode: MenuBarDisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) }
    }

    @Published var iconOnlyWhenNoMedia: Bool {
        didSet { defaults.set(iconOnlyWhenNoMedia, forKey: Key.iconOnlyWhenNoMedia) }
    }

    @Published var maximumCharacters: Int {
        didSet { defaults.set(maximumCharacters, forKey: Key.maximumCharacters) }
    }

    @Published var scrollingEnabled: Bool {
        didSet { defaults.set(scrollingEnabled, forKey: Key.scrollingEnabled) }
    }

    @Published var marqueeMode: MarqueeMode {
        didSet { defaults.set(marqueeMode.rawValue, forKey: Key.marqueeMode) }
    }

    @Published var scrollingSpeed: Double {
        didSet { defaults.set(scrollingSpeed, forKey: Key.scrollingSpeed) }
    }

    @Published var fontWeight: MenuBarFontWeight {
        didSet { defaults.set(fontWeight.rawValue, forKey: Key.fontWeight) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayMode = defaults.string(forKey: Key.displayMode)
            .flatMap(MenuBarDisplayMode.init(rawValue:)) ?? .titleAndArtist

        if defaults.object(forKey: Key.iconOnlyWhenNoMedia) == nil {
            iconOnlyWhenNoMedia = true
        } else {
            iconOnlyWhenNoMedia = defaults.bool(forKey: Key.iconOnlyWhenNoMedia)
        }

        let storedMaximumCharacters = defaults.integer(forKey: Key.maximumCharacters)
        maximumCharacters = storedMaximumCharacters == 0 ? 20 : min(
            max(storedMaximumCharacters, MarqueeSettingRange.minimumCharacters),
            MarqueeSettingRange.maximumCharacters
        )
        scrollingEnabled = defaults.object(forKey: Key.scrollingEnabled) == nil
            ? true
            : defaults.bool(forKey: Key.scrollingEnabled)
        marqueeMode = defaults.string(forKey: Key.marqueeMode)
            .flatMap(MarqueeMode.init(rawValue:)) ?? .loop
        let storedSpeed = defaults.double(forKey: Key.scrollingSpeed)
        scrollingSpeed = storedSpeed == 0 ? 28 : min(
            max(storedSpeed, MarqueeSettingRange.minimumSpeed),
            MarqueeSettingRange.maximumSpeed
        )
        fontWeight = defaults.string(forKey: Key.fontWeight)
            .flatMap(MenuBarFontWeight.init(rawValue:)) ?? .medium
    }

    init(
        transientDisplayMode: MenuBarDisplayMode,
        iconOnlyWhenNoMedia: Bool,
        maximumCharacters: Int = 20,
        scrollingEnabled: Bool = true,
        marqueeMode: MarqueeMode = .loop,
        scrollingSpeed: Double = 28,
        fontWeight: MenuBarFontWeight = .medium
    ) {
        defaults = .standard
        displayMode = transientDisplayMode
        self.iconOnlyWhenNoMedia = iconOnlyWhenNoMedia
        self.maximumCharacters = maximumCharacters
        self.scrollingEnabled = scrollingEnabled
        self.marqueeMode = marqueeMode
        self.scrollingSpeed = scrollingSpeed
        self.fontWeight = fontWeight
    }
}
