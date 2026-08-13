import Foundation

enum DetailsPanelLayout {
    static func height(recognitionEnabled: Bool) -> CGFloat {
        recognitionEnabled ? 140 : 116
    }

    static func artworkSize(recognitionEnabled: Bool) -> CGFloat {
        recognitionEnabled ? 112 : 84
    }

    static func padding(recognitionEnabled: Bool) -> CGFloat {
        recognitionEnabled ? 14 : 16
    }
}
