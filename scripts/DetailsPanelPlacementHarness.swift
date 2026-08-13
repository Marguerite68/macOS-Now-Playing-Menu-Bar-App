import AppKit

@main
struct DetailsPanelPlacementHarness {
    static func main() {
        let leftDisplay = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let rightDisplay = CGRect(x: 1_440, y: 0, width: 1_440, height: 900)
        let statusButtonFrame = CGRect(x: 288, y: 876, width: 24, height: 24)

        let selectedDisplay = DetailsPanelPlacement.screenFrame(
            containing: statusButtonFrame,
            availableScreens: [leftDisplay, rightDisplay],
            fallback: rightDisplay
        )

        precondition(
            selectedDisplay == leftDisplay,
            "the status button must determine the panel display, not the active-display fallback"
        )

        let panelFrame = DetailsPanelPlacement.panelFrame(
            buttonFrame: statusButtonFrame,
            screenVisibleFrame: selectedDisplay,
            contentSize: CGSize(width: 390, height: 116)
        )

        precondition(
            leftDisplay.contains(panelFrame),
            "the detail panel must remain fully on the display where it was opened"
        )
        precondition(
            panelFrame.maxY == statusButtonFrame.minY - 6,
            "the detail panel must appear directly below the status button"
        )
        precondition(
            !DetailsPanelPlacement.shouldDismiss(
                panelFrame: panelFrame,
                forClickAt: CGPoint(x: panelFrame.midX, y: panelFrame.midY)
            ),
            "a click within the detail panel must keep it open"
        )
        precondition(
            DetailsPanelPlacement.shouldDismiss(
                panelFrame: panelFrame,
                forClickAt: CGPoint(x: rightDisplay.midX, y: rightDisplay.midY)
            ),
            "a click outside the detail panel must dismiss it"
        )

        print("PASS: detail panel is anchored below its status button and dismisses on outside clicks")
    }
}
