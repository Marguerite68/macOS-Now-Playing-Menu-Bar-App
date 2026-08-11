import AppKit
import Foundation

enum MenuBarLayout {
    static let minimumTextWidth: CGFloat = 64
    static let maximumTextWidth: CGFloat = 230
    static let fontSize: CGFloat = 13
}

struct MarqueeConfiguration {
    let initialDelay: TimeInterval
    let endDelay: TimeInterval
    let pointsPerSecond: CGFloat

    static let menuBar = MarqueeConfiguration(
        initialDelay: 1.4,
        endDelay: 1.0,
        pointsPerSecond: 28
    )
}

struct MarqueeMetrics {
    let textWidth: CGFloat
    let viewportWidth: CGFloat
    let travelDistance: CGFloat

    var needsScrolling: Bool {
        travelDistance > 0.5
    }

    static func menuBar(text: String) -> MarqueeMetrics {
        let textWidth = TextMeasurer.width(
            of: text,
            font: .systemFont(ofSize: MenuBarLayout.fontSize, weight: .regular)
        )
        let viewportWidth = min(
            max(textWidth, MenuBarLayout.minimumTextWidth),
            MenuBarLayout.maximumTextWidth
        )

        return MarqueeMetrics(
            textWidth: textWidth,
            viewportWidth: viewportWidth,
            travelDistance: max(0, textWidth - viewportWidth)
        )
    }
}

enum TextMeasurer {
    static func width(of text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }
}
