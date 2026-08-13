import AppKit
import QuartzCore
import SwiftUI

private struct MarqueeRenderState: Equatable {
    let title: String
    let fullText: String
    let viewportWidth: CGFloat
    let shouldScroll: Bool
    let isPlaying: Bool
    let trackID: String
    let mode: MarqueeMode
    let speed: CGFloat
    let fontWeight: MenuBarFontWeight
}

@MainActor
final class MarqueeLayerView: NSView {
    private static let animationKey = "NowPlayingBar.marquee"
    private let textLayer = CATextLayer()
    private var renderState: MarqueeRenderState?
    private var needsAnimationRestart = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true

        textLayer.alignmentMode = .left
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        textLayer.font = NSFont.systemFont(
            ofSize: MenuBarLayout.fontSize,
            weight: .regular
        )
        textLayer.fontSize = MenuBarLayout.fontSize
        textLayer.foregroundColor = NSColor.labelColor.cgColor
        textLayer.isWrapped = false
        textLayer.truncationMode = .none
        layer?.addSublayer(textLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        guard let renderState else { return }

        let contentLayout = MarqueeContentLayout.make(
            text: renderState.fullText,
            viewportWidth: bounds.width,
            mode: renderState.mode,
            fontWeight: renderState.fontWeight
        )
        let renderedText = renderState.shouldScroll
            ? contentLayout.renderedText
            : renderState.title
        let textWidth = max(
            bounds.width,
            TextMeasurer.width(
                of: renderedText,
                font: .systemFont(
                    ofSize: MenuBarLayout.fontSize,
                    weight: renderState.fontWeight.nsWeight
                )
            )
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textLayer.string = renderedText
        textLayer.frame = CGRect(
            x: 0,
            y: floor((bounds.height - 17) / 2),
            width: textWidth,
            height: 17
        )
        CATransaction.commit()

        if needsAnimationRestart {
            installAnimationIfNeeded()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textLayer.foregroundColor = NSColor.labelColor.cgColor
        CATransaction.commit()
    }

    func update(with presentation: StatusBarPresentation) {
        let newState = MarqueeRenderState(
            title: presentation.title,
            fullText: presentation.fullText,
            viewportWidth: presentation.textViewportWidth,
            shouldScroll: presentation.shouldScroll,
            isPlaying: presentation.isPlaying,
            trackID: presentation.trackID,
            mode: presentation.marqueeMode,
            speed: presentation.scrollingSpeed,
            fontWeight: presentation.fontWeight
        )
        guard newState != renderState else { return }

        renderState = newState
        stopAndReset()
        textLayer.font = NSFont.systemFont(
            ofSize: MenuBarLayout.fontSize,
            weight: newState.fontWeight.nsWeight
        )
        needsLayout = true

        if newState.shouldScroll && newState.isPlaying {
            needsAnimationRestart = true
            layoutSubtreeIfNeeded()
        }
    }

    func stopAndReset() {
        textLayer.removeAnimation(forKey: Self.animationKey)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textLayer.setAffineTransform(.identity)
        CATransaction.commit()
        needsAnimationRestart = false
    }

    private func installAnimationIfNeeded() {
        guard let renderState,
              renderState.shouldScroll,
              renderState.isPlaying,
              bounds.width > 0 else { return }

        let contentLayout = MarqueeContentLayout.make(
            text: renderState.fullText,
            viewportWidth: bounds.width,
            mode: renderState.mode,
            fontWeight: renderState.fontWeight
        )
        guard let plan = MarqueeAnimationPlan.make(
            travelDistance: contentLayout.travelDistance,
            mode: renderState.mode,
            pointsPerSecond: renderState.speed
        ) else {
            needsAnimationRestart = false
            return
        }

        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = plan.values
        animation.keyTimes = plan.keyTimes
        animation.duration = plan.duration
        animation.repeatCount = .infinity
        animation.calculationMode = .linear
        animation.isRemovedOnCompletion = false
        textLayer.add(animation, forKey: Self.animationKey)
        needsAnimationRestart = false
    }
}

@MainActor
final class StatusItemContentView: NSView {
    private let iconView = NSImageView()
    private let marqueeView = MarqueeLayerView()
    private let qualityBadgeView = QualityBadgeNSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(iconView)
        addSubview(marqueeView)
        addSubview(qualityBadgeView)
        iconView.imageScaling = .scaleProportionallyDown
        qualityBadgeView.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        let iconX = MenuBarLayout.horizontalPadding
        iconView.frame = CGRect(
            x: iconX,
            y: floor((bounds.height - MenuBarLayout.iconWidth) / 2),
            width: MenuBarLayout.iconWidth,
            height: MenuBarLayout.iconWidth
        )
        let badgeSpacing: CGFloat = qualityBadgeView.isHidden ? 0 : 5
        let badgeWidth = qualityBadgeView.isHidden ? 0 : qualityBadgeView.badgeWidth
        qualityBadgeView.frame = CGRect(
            x: bounds.width - MenuBarLayout.horizontalPadding - badgeWidth,
            y: floor((bounds.height - 14) / 2),
            width: badgeWidth,
            height: 14
        )
        marqueeView.frame = CGRect(
            x: iconView.frame.maxX + MenuBarLayout.iconTextSpacing,
            y: 0,
            width: max(0, bounds.width - iconView.frame.maxX
                - MenuBarLayout.iconTextSpacing - MenuBarLayout.horizontalPadding
                - badgeSpacing - badgeWidth),
            height: bounds.height
        )
    }

    func update(with presentation: StatusBarPresentation) {
        let image = NSImage(
            systemSymbolName: presentation.iconName,
            accessibilityDescription: "NowPlayingBar"
        )
        image?.isTemplate = true
        iconView.image = image
        qualityBadgeView.update(tier: presentation.qualityBadge)
        marqueeView.isHidden = presentation.title.isEmpty
        marqueeView.update(with: presentation)
        needsLayout = true
    }
}

@MainActor
private final class QualityBadgeNSView: NSView {
    private var tier: AudioQualityTier?
    private let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.imageScaling = .scaleProportionallyDown
        imageView.contentTintColor = .labelColor
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var badgeWidth: CGFloat {
        tier?.badgeWidth ?? 0
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        imageView.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        imageView.contentTintColor = .labelColor
        needsDisplay = true
    }

    func update(tier: AudioQualityTier?) {
        guard self.tier != tier else { return }
        self.tier = tier
        isHidden = tier == nil
        imageView.image = tier.flatMap(AudioQualityBadgeAsset.image(for:))
        imageView.isHidden = imageView.image == nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let tier else { return }

        guard imageView.image == nil else { return }

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
        NSColor.labelColor.withAlphaComponent(0.82).setStroke()
        path.lineWidth = 1
        path.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7.5, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
            .kern: 0.2
        ]
        (tier.badgeText as NSString).draw(
            in: CGRect(x: 1, y: 2.2, width: bounds.width - 2, height: 10),
            withAttributes: attributes
        )
    }
}

struct MarqueeTextPreview: NSViewRepresentable {
    let presentation: StatusBarPresentation

    func makeNSView(context: Context) -> MarqueeLayerView {
        MarqueeLayerView()
    }

    func updateNSView(_ nsView: MarqueeLayerView, context: Context) {
        nsView.update(with: presentation)
    }

    static func dismantleNSView(_ nsView: MarqueeLayerView, coordinator: ()) {
        nsView.stopAndReset()
    }
}
