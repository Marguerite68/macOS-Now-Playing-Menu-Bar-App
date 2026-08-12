import AppKit
import Foundation

enum MenuBarLayout {
    static let maximumTextWidth: CGFloat = 260
    static let fontSize: CGFloat = 13
    static let iconWidth: CGFloat = 16
    static let iconTextSpacing: CGFloat = 5
    static let horizontalPadding: CGFloat = 8
}

extension MenuBarFontWeight {
    var nsWeight: NSFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}

struct MarqueeMetrics {
    let textWidth: CGFloat
    let viewportWidth: CGFloat
    let travelDistance: CGFloat

    var needsScrolling: Bool {
        travelDistance > 0.5
    }

    static func menuBar(
        text: String,
        maximumCharacters: Int = 20,
        fontWeight: MenuBarFontWeight = .medium
    ) -> MarqueeMetrics {
        let textWidth = TextMeasurer.width(
            of: text,
            font: .systemFont(ofSize: MenuBarLayout.fontSize, weight: fontWeight.nsWeight)
        )
        let prefix = String(text.prefix(maximumCharacters))
        let limitedWidth = TextMeasurer.width(
            of: prefix,
            font: .systemFont(ofSize: MenuBarLayout.fontSize, weight: fontWeight.nsWeight)
        )
        let hasOverflow = text.count > maximumCharacters
        let desiredWidth = hasOverflow ? limitedWidth : textWidth
        let viewportWidth = min(max(desiredWidth, 1), MenuBarLayout.maximumTextWidth)

        return MarqueeMetrics(
            textWidth: textWidth,
            viewportWidth: viewportWidth,
            travelDistance: hasOverflow ? max(0, textWidth - viewportWidth) : 0
        )
    }
}

enum MenuBarTextLimiter {
    static func displayedText(
        _ text: String,
        maximumCharacters: Int,
        scrollingEnabled: Bool
    ) -> String {
        guard text.count > maximumCharacters else { return text }
        guard !scrollingEnabled else { return text }
        return String(text.prefix(maximumCharacters)) + "…"
    }
}

struct MarqueeAnimationPlan {
    let values: [CGFloat]
    let keyTimes: [NSNumber]
    let duration: TimeInterval

    static func make(
        travelDistance: CGFloat,
        mode: MarqueeMode,
        pointsPerSecond: CGFloat
    ) -> MarqueeAnimationPlan? {
        guard travelDistance > 0.5, pointsPerSecond > 0 else { return nil }

        let headDelay = 1.4
        let endDelay = 1.0
        let movementDuration = TimeInterval(travelDistance / pointsPerSecond)

        switch mode {
        case .loop:
            return MarqueeAnimationPlan(
                values: [0, -travelDistance],
                keyTimes: [0, 1],
                duration: movementDuration
            )
        case .pingPong:
            let duration = headDelay + movementDuration + endDelay + movementDuration
            return MarqueeAnimationPlan(
                values: [0, 0, -travelDistance, -travelDistance, 0],
                keyTimes: [
                    0,
                    NSNumber(value: headDelay / duration),
                    NSNumber(value: (headDelay + movementDuration) / duration),
                    NSNumber(value: (headDelay + movementDuration + endDelay) / duration),
                    1
                ],
                duration: duration
            )
        }
    }
}

struct MarqueeContentLayout {
    static let loopSeparator = "    "

    let renderedText: String
    let travelDistance: CGFloat

    static func make(
        text: String,
        viewportWidth: CGFloat,
        mode: MarqueeMode,
        fontWeight: MenuBarFontWeight
    ) -> MarqueeContentLayout {
        let font = NSFont.systemFont(
            ofSize: MenuBarLayout.fontSize,
            weight: fontWeight.nsWeight
        )

        switch mode {
        case .loop:
            let firstSegment = text + loopSeparator
            return MarqueeContentLayout(
                renderedText: firstSegment + text,
                travelDistance: TextMeasurer.width(of: firstSegment, font: font)
            )
        case .pingPong:
            let textWidth = TextMeasurer.width(of: text, font: font)
            return MarqueeContentLayout(
                renderedText: text,
                travelDistance: max(0, textWidth - viewportWidth)
            )
        }
    }
}

enum TextMeasurer {
    static func width(of text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }
}
