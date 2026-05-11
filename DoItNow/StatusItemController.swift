import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let store: TodoStore
    private let focusMode: FocusModeController

    private var cancellables = Set<AnyCancellable>()
    private var appearanceObserver: NSKeyValueObservation?

    init(store: TodoStore, focusMode: FocusModeController) {
        self.store = store
        self.focusMode = focusMode
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        configurePopover()
        configureStatusItem()
        observe()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        let root = PopoverView(store: store, focusMode: focusMode)
        popover.contentViewController = NSHostingController(rootView: root)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.wantsLayer = true
        updateIcon()
    }

    private func observe() {
        store.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        if let button = statusItem.button {
            appearanceObserver = button.observe(\.effectiveAppearance) { [weak self] _, _ in
                guard let self else { return }
                Task { @MainActor in self.updateIcon() }
            }
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = StatusBarIcon.make(
            count: store.unfinishedCount,
            appearance: button.effectiveAppearance
        )
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let launchItem = NSMenuItem(
            title: NSLocalizedString("Launch at Login", comment: "Right-click menu item to toggle launch at login"),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("Quit", comment: "Right-click menu item to quit the app"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func pulseIcon() {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        guard let layer = button.layer else { return }

        centerAnimationAnchor(for: layer)
        layer.removeAnimation(forKey: "doitnow.pulse")

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1.0, 0.35, 1.0]
        opacity.keyTimes = [0.0, 0.5, 1.0]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 0.92, 1.0]
        scale.keyTimes = [0.0, 0.5, 1.0]

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = 0.7
        group.repeatCount = 5
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.isRemovedOnCompletion = true

        layer.add(group, forKey: "doitnow.pulse")
    }

    private func centerAnimationAnchor(for layer: CALayer) {
        let centeredAnchor = CGPoint(x: 0.5, y: 0.5)
        guard layer.anchorPoint != centeredAnchor else { return }

        let oldAnchor = layer.anchorPoint
        let oldPosition = layer.position
        let bounds = layer.bounds

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.anchorPoint = centeredAnchor
        layer.position = CGPoint(
            x: oldPosition.x + (centeredAnchor.x - oldAnchor.x) * bounds.width,
            y: oldPosition.y + (centeredAnchor.y - oldAnchor.y) * bounds.height
        )
        CATransaction.commit()
    }
}
