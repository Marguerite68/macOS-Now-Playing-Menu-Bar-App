import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, ObservableObject {
    private let manager: NowPlayingManager
    private let settings: AppSettings
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusItemContentView = StatusItemContentView()
    private let detailsPopover = NSPopover()
    private var preferencesWindowController: PreferencesWindowController?
    private var presentationObserver: StatusBarPresentationObserver?

    init(manager: NowPlayingManager, settings: AppSettings) {
        self.manager = manager
        self.settings = settings
        super.init()

        configureStatusButton()
        configureDetailsPopover()
        observePresentationChanges()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(handleStatusButtonClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = nil
        button.title = ""
        statusItemContentView.frame = button.bounds
        statusItemContentView.autoresizingMask = [.width, .height]
        button.addSubview(statusItemContentView)
    }

    private func configureDetailsPopover() {
        detailsPopover.behavior = .transient
        detailsPopover.contentViewController = NSHostingController(
            rootView: NowPlayingDetailsView(manager: manager)
        )
    }

    private func observePresentationChanges() {
        presentationObserver = StatusBarPresentationObserver(
            manager: manager,
            settings: settings
        ) { [weak self] presentation in
            self?.updateStatusButton(with: presentation)
        }
    }

    private func updateStatusButton(with presentation: StatusBarPresentation) {
        guard let button = statusItem.button else { return }

        statusItem.isVisible = !presentation.isHidden
        if presentation.isHidden {
            detailsPopover.performClose(nil)
            return
        }

        button.toolTip = presentation.accessibilityLabel
        statusItem.length = presentation.statusItemLength
        statusItemContentView.frame = button.bounds
        statusItemContentView.update(with: presentation)
    }

    @objc private func handleStatusButtonClick(_ sender: NSStatusBarButton) {
        switch NSApp.currentEvent?.type {
        case .rightMouseUp:
            detailsPopover.performClose(nil)
            showContextMenu(from: sender)
        default:
            toggleDetailsPopover(from: sender)
        }
    }

    private func toggleDetailsPopover(from button: NSStatusBarButton) {
        if detailsPopover.isShown {
            detailsPopover.performClose(nil)
        } else {
            detailsPopover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let preferencesItem = NSMenuItem(
            title: "设置…",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        preferencesItem.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: "设置"
        )
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 NowPlayingBar",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = NSImage(
            systemSymbolName: "power",
            accessibilityDescription: "退出"
        )
        menu.addItem(quitItem)

        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height),
            in: button
        )
    }

    @objc private func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(
                settings: settings,
                manager: manager
            )
        }

        preferencesWindowController?.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}

@MainActor
private final class PreferencesWindowController: NSWindowController {
    init(settings: AppSettings, manager: NowPlayingManager) {
        let rootView = PreferencesView(settings: settings, manager: manager)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "NowPlayingBar 偏好设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 540, height: 500))
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
