import CoreGraphics

enum DetailsPanelPlacement {
    static func screenFrame(
        containing point: CGPoint,
        availableScreens: [CGRect],
        fallback: CGRect
    ) -> CGRect {
        availableScreens.first(where: { $0.contains(point) }) ?? fallback
    }

    static func screenFrame(
        containing buttonFrame: CGRect,
        availableScreens: [CGRect],
        fallback: CGRect
    ) -> CGRect {
        screenFrame(
            containing: CGPoint(x: buttonFrame.midX, y: buttonFrame.midY),
            availableScreens: availableScreens,
            fallback: fallback
        )
    }

    static func panelFrame(
        buttonFrame: CGRect,
        screenVisibleFrame: CGRect,
        contentSize: CGSize
    ) -> CGRect {
        let horizontalOrigin = min(
            max(buttonFrame.midX - contentSize.width / 2, screenVisibleFrame.minX),
            screenVisibleFrame.maxX - contentSize.width
        )
        let verticalOrigin = max(
            screenVisibleFrame.minY,
            buttonFrame.minY - contentSize.height - 6
        )

        return CGRect(
            x: horizontalOrigin,
            y: verticalOrigin,
            width: contentSize.width,
            height: contentSize.height
        ).integral
    }

    static func shouldDismiss(panelFrame: CGRect, forClickAt screenPoint: CGPoint) -> Bool {
        !panelFrame.contains(screenPoint)
    }
}
