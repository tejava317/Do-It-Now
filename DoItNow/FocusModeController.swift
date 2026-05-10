import Foundation
import Combine

@MainActor
final class FocusModeController: ObservableObject {
    @Published private(set) var isOn: Bool = false

    var onPulse: (() -> Void)?

    private let interval: TimeInterval = 10 * 60
    private var timer: Timer?
    private weak var store: TodoStore?

    init(store: TodoStore) {
        self.store = store
    }

    func toggle() {
        isOn ? turnOff() : turnOn()
    }

    private func turnOn() {
        isOn = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    private func turnOff() {
        isOn = false
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let store, !store.items.isEmpty else { return }
        onPulse?()
    }
}
