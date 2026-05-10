import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: TodoStore?
    private var focusMode: FocusModeController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = TodoStore()
        let focusMode = FocusModeController(store: store)
        let controller = StatusItemController(store: store, focusMode: focusMode)

        focusMode.onPulse = { [weak controller] in
            controller?.pulseIcon()
        }

        self.store = store
        self.focusMode = focusMode
        self.statusItemController = controller
    }
}
