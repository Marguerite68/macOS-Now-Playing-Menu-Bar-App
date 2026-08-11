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

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let displayMode = "menuBarDisplayMode"
        static let iconOnlyWhenNoMedia = "iconOnlyWhenNoMedia"
    }

    @Published var displayMode: MenuBarDisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) }
    }

    @Published var iconOnlyWhenNoMedia: Bool {
        didSet { defaults.set(iconOnlyWhenNoMedia, forKey: Key.iconOnlyWhenNoMedia) }
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
    }

    init(transientDisplayMode: MenuBarDisplayMode, iconOnlyWhenNoMedia: Bool) {
        defaults = .standard
        displayMode = transientDisplayMode
        self.iconOnlyWhenNoMedia = iconOnlyWhenNoMedia
    }
}
