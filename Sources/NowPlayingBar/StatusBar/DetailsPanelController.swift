import AppKit
import Combine
import SwiftUI

@MainActor
final class DetailsPanelController: NSObject {
    private var contentSize: NSSize
    private let panel: NSPanel
    private var sizeCancellable: AnyCancellable?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    init(
        manager: NowPlayingManager,
        settings: AppSettings,
        audioQualityManager: AudioQualityManager
    ) {
        contentSize = DetailsPanelLayout.contentSize(
            for: manager.mediaInfo,
            recognitionEnabled: settings.audioQualityRecognitionEnabled
        )
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        let materialView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentSize))
        materialView.material = .popover
        materialView.blendingMode = .behindWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = 14
        materialView.layer?.cornerCurve = .continuous
        materialView.layer?.masksToBounds = true

        let hostingView = NSHostingView(
            rootView: NowPlayingDetailsView(
                manager: manager,
                settings: settings,
                audioQualityManager: audioQualityManager
            )
        )
        hostingView.frame = materialView.bounds
        hostingView.autoresizingMask = [.width, .height]
        materialView.addSubview(hostingView)
        panel.contentView = materialView
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // The system shadow follows the rectangular panel frame, not the
        // rounded material mask, so it creates a visible square outline.
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .stationary, .fullScreenAuxiliary]

        sizeCancellable = Publishers.CombineLatest(
            manager.$mediaInfo,
            settings.$audioQualityRecognitionEnabled
        )
        .map { mediaInfo, recognitionEnabled in
            DetailsPanelLayout.contentSize(
                for: mediaInfo,
                recognitionEnabled: recognitionEnabled
            )
        }
        .removeDuplicates()
        .sink { [weak self] size in
            self?.updateContentSize(size)
        }
    }

    private func updateContentSize(_ size: NSSize) {
        guard contentSize != size else { return }
        let previousSize = contentSize
        contentSize = size
        var frame = panel.frame
        frame.origin.x -= (size.width - previousSize.width) / 2
        frame.origin.y -= size.height - previousSize.height
        frame.size = size
        if let visibleFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            frame.origin.x = min(
                max(frame.origin.x, visibleFrame.minX),
                visibleFrame.maxX - size.width
            )
            frame.origin.y = min(
                max(frame.origin.y, visibleFrame.minY),
                visibleFrame.maxY - size.height
            )
        }
        panel.setFrame(frame, display: panel.isVisible, animate: panel.isVisible)
        panel.contentView?.frame = NSRect(origin: .zero, size: contentSize)
    }

    var isShown: Bool {
        panel.isVisible
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if isShown {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    func close() {
        panel.orderOut(nil)
        removeMouseMonitors()
    }

    private func show(relativeTo button: NSStatusBarButton) {
        guard let statusBarWindow = button.window,
              let fallbackScreen = statusBarWindow.screen ?? NSScreen.main else {
            return
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrame = statusBarWindow.convertToScreen(buttonFrameInWindow)

        let openingScreenFrame = DetailsPanelPlacement.screenFrame(
            containing: buttonFrame,
            availableScreens: NSScreen.screens.map(\.frame),
            fallback: fallbackScreen.frame
        )
        let openingScreen = NSScreen.screens.first(where: { $0.frame == openingScreenFrame }) ?? fallbackScreen
        let frame = DetailsPanelPlacement.panelFrame(
            buttonFrame: buttonFrame,
            screenVisibleFrame: openingScreen.visibleFrame,
            contentSize: contentSize
        )

        panel.setFrame(frame, display: true)
        installMouseMonitors()
        panel.orderFrontRegardless()
    }

    private func installMouseMonitors() {
        removeMouseMonitors()

        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.dismissIfClickIsOutsidePanel()
            }
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissIfClickIsOutsidePanel()
            }
        }
    }

    private func dismissIfClickIsOutsidePanel() {
        guard isShown,
              DetailsPanelPlacement.shouldDismiss(panelFrame: panel.frame, forClickAt: NSEvent.mouseLocation) else {
            return
        }

        close()
    }

    private func removeMouseMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }
}
