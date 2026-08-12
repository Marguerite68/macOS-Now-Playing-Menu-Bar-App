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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(iconView)
        addSubview(marqueeView)
        iconView.imageScaling = .scaleProportionallyDown
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
        marqueeView.frame = CGRect(
            x: iconView.frame.maxX + MenuBarLayout.iconTextSpacing,
            y: 0,
            width: max(0, bounds.width - iconView.frame.maxX
                - MenuBarLayout.iconTextSpacing - MenuBarLayout.horizontalPadding),
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
        marqueeView.isHidden = presentation.title.isEmpty
        marqueeView.update(with: presentation)
        needsLayout = true
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
