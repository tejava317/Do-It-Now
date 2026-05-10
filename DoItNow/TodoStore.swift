import Foundation
import Combine

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let storageKey = "DoItNow.items.v1"
    private var addUndoStack: [UUID] = []

    init() {
        load()
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed)
        items.append(item)
        addUndoStack.append(item.id)
        save()
    }

    func complete(id: UUID) {
        items.removeAll { $0.id == id }
        addUndoStack.removeAll { $0 == id }
        save()
    }

    func completeAll() {
        guard !items.isEmpty else { return }
        items.removeAll()
        addUndoStack.removeAll()
        save()
    }

    @discardableResult
    func update(id: UUID, title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = items.firstIndex(where: { $0.id == id }) else {
            return false
        }

        guard items[index].title != trimmed else { return true }
        items[index].title = trimmed
        save()
        return true
    }

    @discardableResult
    func move(id: UUID, to targetID: UUID, saveImmediately: Bool = true) -> Bool {
        guard id != targetID,
              let sourceIndex = items.firstIndex(where: { $0.id == id }),
              let targetIndex = items.firstIndex(where: { $0.id == targetID }) else {
            return false
        }

        let item = items.remove(at: sourceIndex)
        items.insert(item, at: targetIndex)
        if saveImmediately {
            save()
        }
        return true
    }

    func saveCurrentOrder() {
        save()
    }

    func undoLastAdd() {
        guard let id = addUndoStack.popLast() else { return }
        items.removeAll { $0.id == id }
        save()
    }

    var unfinishedCount: Int { items.count }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return
        }
        items = decoded
    }
}
