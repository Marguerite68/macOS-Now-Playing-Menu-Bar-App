import AppKit
import QuartzCore
import SwiftUI

struct ScrollingTextView: NSViewRepresentable {
    let text: String
    let isPlaying: Bool
    let resetID: UUID

    private var metrics: MarqueeMetrics {
        .menuBar(text: text)
    }

    func makeNSView(context: Context) -> MarqueeContainerView {
        MarqueeContainerView()
    }

    func updateNSView(_ nsView: MarqueeContainerView, context: Context) {
        nsView.update(
            text: text,
            metrics: metrics,
            isPlaying: isPlaying,
            resetID: resetID
        )
    }

    static func dismantleNSView(_ nsView: MarqueeContainerView, coordinator: ()) {
        nsView.stopAnimation()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: MarqueeContainerView,
        context: Context
    ) -> CGSize? {
        CGSize(width: metrics.viewportWidth, height: 18)
    }
}

@MainActor
final class MarqueeContainerView: NSView {
    private static let animationKey = "NowPlayingBar.marquee"

    private let textField = NSTextField(labelWithString: "")
    private var currentText = ""
    private var currentResetID: UUID?
    private var currentIsPlaying = false
    private var metrics = MarqueeMetrics(
        textWidth: 0,
        viewportWidth: MenuBarLayout.minimumTextWidth,
        travelDistance: 0
    )
    private var animationIsPaused = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.masksToBounds = true

        textField.font = .systemFont(ofSize: MenuBarLayout.fontSize, weight: .regular)
        textField.textColor = .labelColor
        textField.backgroundColor = .clear
        textField.isBezeled = false
        textField.isBordered = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.lineBreakMode = .byClipping
        textField.maximumNumberOfLines = 1
        textField.wantsLayer = true
        addSubview(textField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let textHeight = ceil(textField.intrinsicContentSize.height)
        textField.frame = NSRect(
            x: 0,
            y: floor((bounds.height - textHeight) / 2),
            width: max(metrics.textWidth, bounds.width),
            height: textHeight
        )
    }

    func update(
        text: String,
        metrics: MarqueeMetrics,
        isPlaying: Bool,
        resetID: UUID
    ) {
        let shouldRestart = currentText != text
            || currentResetID != resetID
            || self.metrics.travelDistance != metrics.travelDistance

        currentText = text
        currentResetID = resetID
        self.metrics = metrics
        textField.stringValue = text

        needsLayout = true
        layoutSubtreeIfNeeded()

        if shouldRestart {
            restartAnimation(isPlaying: isPlaying)
        } else if currentIsPlaying != isPlaying {
            isPlaying ? resumeAnimation() : pauseAnimation()
        }

        currentIsPlaying = isPlaying
    }

    func stopAnimation() {
        guard let textLayer = textField.layer else { return }
        textLayer.removeAnimation(forKey: Self.animationKey)
        textLayer.speed = 1
        textLayer.timeOffset = 0
        textLayer.beginTime = 0
        textLayer.setAffineTransform(.identity)
        animationIsPaused = false
    }

    private func restartAnimation(isPlaying: Bool) {
        stopAnimation()
        guard metrics.needsScrolling, let textLayer = textField.layer else { return }

        let configuration = MarqueeConfiguration.menuBar
        let movementDuration = TimeInterval(metrics.travelDistance / configuration.pointsPerSecond)
        let cycleDuration = configuration.initialDelay + movementDuration + configuration.endDelay
        guard cycleDuration > 0 else { return }

        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, 0, -metrics.travelDistance, -metrics.travelDistance]
        animation.keyTimes = [
            0,
            NSNumber(value: configuration.initialDelay / cycleDuration),
            NSNumber(value: (configuration.initialDelay + movementDuration) / cycleDuration),
            1
        ]
        animation.duration = cycleDuration
        animation.repeatCount = .infinity
        animation.calculationMode = .linear
        animation.isRemovedOnCompletion = false
        textLayer.add(animation, forKey: Self.animationKey)

        if !isPlaying {
            pauseAnimation()
        }
    }

    private func pauseAnimation() {
        guard metrics.needsScrolling,
              !animationIsPaused,
              let textLayer = textField.layer,
              textLayer.animation(forKey: Self.animationKey) != nil else { return }

        let pausedTime = textLayer.convertTime(CACurrentMediaTime(), from: nil)
        textLayer.speed = 0
        textLayer.timeOffset = pausedTime
        animationIsPaused = true
    }

    private func resumeAnimation() {
        guard animationIsPaused, let textLayer = textField.layer else { return }

        let pausedTime = textLayer.timeOffset
        textLayer.speed = 1
        textLayer.timeOffset = 0
        textLayer.beginTime = 0
        let elapsedPause = textLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        textLayer.beginTime = elapsedPause
        animationIsPaused = false
    }
}
