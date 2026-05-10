import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct PopoverView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var focusMode: FocusModeController

    @State private var inputText: String = ""
    @State private var invalidAddAttempts: CGFloat = 0
    @State private var finishEditingRequests: Int = 0
    @State private var completeAllRequests: Int = 0
    @State private var isCompletingAll: Bool = false
    @State private var draggedItemID: UUID?
    @State private var hasUnsavedDragMove: Bool = false
    @FocusState private var inputFocused: Bool

    private let listHeight: CGFloat = 150
    private let completeAllDelayStep: Double = 0.15

    var body: some View {
        VStack(spacing: 0) {
            list
            Divider()
            input
            Divider()
            footer
        }
        .frame(width: 300)
        .background(undoShortcut)
        .onAppear { inputFocused = true }
    }

    private var undoShortcut: some View {
        Button("Undo Last Add") {
            withAnimation(.easeOut(duration: 0.2)) {
                store.undoLastAdd()
            }
        }
        .keyboardShortcut("z", modifiers: .command)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var list: some View {
        if store.items.isEmpty {
            Text("No tasks")
                .foregroundStyle(.secondary)
                .font(.callout)
                .frame(maxWidth: .infinity)
                .frame(height: listHeight)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(store.items) { item in
                            TodoRow(
                                item: item,
                                finishEditingRequests: finishEditingRequests,
                                completeAllRequests: completeAllRequests,
                                completeAllDelay: completeAllDelay(for: item),
                                isDragging: draggedItemID == item.id,
                                onRename: { newTitle in
                                    store.update(id: item.id, title: newTitle)
                                }
                            ) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    store.complete(id: item.id)
                                }
                            }
                            .onDrag {
                                finishCurrentEdit()
                                draggedItemID = item.id
                                hasUnsavedDragMove = false
                                return NSItemProvider(object: item.id.uuidString as NSString)
                            } preview: {
                                Color.clear
                                    .frame(width: 1, height: 1)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: TodoRowDropDelegate(
                                    item: item,
                                    draggedItemID: $draggedItemID,
                                    move: moveDraggedItem,
                                    finish: finishDragDrop
                                )
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, minHeight: listHeight, alignment: .top)
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: finishCurrentEdit)
                }
                .onDrop(of: [.text], isTargeted: nil) { _ in
                    finishDragDrop()
                    return true
                }
            }
            .frame(height: listHeight)
        }
    }

    private var input: some View {
        TextField("Add a task", text: $inputText)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($inputFocused)
            .modifier(ShakeEffect(animatableData: invalidAddAttempts))
            .onSubmit(addCurrentText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    private func addCurrentText() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            rejectEmptyAdd()
            return
        }

        inputText = ""
        withAnimation(.easeOut(duration: 0.2)) {
            store.add(text)
        }
        inputFocused = true
    }

    private func rejectEmptyAdd() {
        inputText = ""
        withAnimation(.linear(duration: 0.35)) {
            invalidAddAttempts += 1
        }
        inputFocused = true
    }

    private func finishCurrentEdit() {
        finishEditingRequests += 1
    }

    private func completeAllDelay(for item: TodoItem) -> Double {
        guard let index = store.items.firstIndex(where: { $0.id == item.id }) else { return 0 }
        return Double(index) * completeAllDelayStep
    }

    private func moveDraggedItem(_ draggedID: UUID, to targetID: UUID) {
        withAnimation(.easeInOut(duration: 0.14)) {
            if store.move(id: draggedID, to: targetID, saveImmediately: false) {
                hasUnsavedDragMove = true
            }
        }
    }

    private func finishDragDrop() {
        if hasUnsavedDragMove {
            store.saveCurrentOrder()
        }
        draggedItemID = nil
        hasUnsavedDragMove = false
    }

    private func toggleFocusMode() {
        if focusMode.isOn {
            focusMode.toggle()
        } else {
            withAnimation(.easeInOut(duration: 0.45)) {
                focusMode.toggle()
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: toggleFocusMode) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(focusMode.isOn ? Color.red : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    Text("Focus Mode")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(focusMode.isOn ? Color.red : Color.secondary)

            Spacer()

            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var actionButton: some View {
        Button(action: completeAllSequentially) {
            Text("Complete All")
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.items.isEmpty || isCompletingAll ? Color.secondary : Color.blue)
        .disabled(store.items.isEmpty || isCompletingAll)
    }

    private func completeAllSequentially() {
        guard !store.items.isEmpty, !isCompletingAll else { return }

        finishCurrentEdit()
        isCompletingAll = true
        completeAllRequests += 1

        let finalDelay = Double(max(store.items.count - 1, 0)) * completeAllDelayStep
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay + 0.55) {
            isCompletingAll = false
        }
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let finishEditingRequests: Int
    let completeAllRequests: Int
    let completeAllDelay: Double
    let isDragging: Bool
    let onRename: (String) -> Bool
    let onComplete: () -> Void

    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var isCompleting: Bool = false
    @State private var isDismissing: Bool = false
    @State private var draftTitle: String = ""
    @State private var invalidEditAttempts: CGFloat = 0
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                completeWithFlourish()
            } label: {
                Image(systemName: isCompleting || isHovered ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isCompleting ? Color.green : (isHovered ? Color.accentColor : Color.secondary))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isCompleting)
            }
            .buttonStyle(.plain)
            .disabled(isCompleting || isDismissing)

            if isEditing {
                TextField(text: $draftTitle) {
                    EmptyView()
                }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .focused($editFocused)
                    .modifier(ShakeEffect(animatableData: invalidEditAttempts))
                    .onSubmit(commitSubmittedEdit)
                    .onExitCommand(perform: cancelEdit)
                    .onChange(of: editFocused) { _, isFocused in
                        if !isFocused {
                            finishEditAfterFocusLoss()
                        }
                    }
            } else {
                Text(item.title)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundStyle(isCompleting ? Color.secondary : Color.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .scaleEffect(isDismissing ? 0.96 : 1, anchor: .leading)
        .offset(x: isDismissing ? 26 : 0)
        .opacity(rowOpacity)
        .onTapGesture(count: 2, perform: beginEditing)
        .onHover { isHovered = $0 }
        .onChange(of: finishEditingRequests) { _, _ in
            finishEditAfterFocusLoss()
        }
        .onChange(of: completeAllRequests) { _, _ in
            completeWithFlourish(after: completeAllDelay)
        }
    }

    private func beginEditing() {
        guard !isEditing else { return }
        draftTitle = item.title
        withAnimation(.easeOut(duration: 0.15)) {
            isEditing = true
        }
        DispatchQueue.main.async {
            editFocused = true
        }
    }

    private func commitSubmittedEdit() {
        guard isEditing else { return }

        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rejectEmptyEdit()
            return
        }

        saveEdit(trimmed)
    }

    private func finishEditAfterFocusLoss() {
        guard isEditing else { return }

        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelEdit()
            return
        }

        saveEdit(trimmed)
    }

    private func saveEdit(_ title: String) {
        guard onRename(title) else {
            rejectEmptyEdit()
            return
        }

        isEditing = false
        draftTitle = ""
    }

    private func cancelEdit() {
        isEditing = false
        draftTitle = ""
    }

    private func rejectEmptyEdit() {
        draftTitle = ""
        withAnimation(.linear(duration: 0.35)) {
            invalidEditAttempts += 1
        }
        DispatchQueue.main.async {
            editFocused = true
        }
    }

    private func completeWithFlourish(after delay: Double = 0) {
        guard !isCompleting, !isDismissing else { return }

        guard delay > 0 else {
            startCompletionAnimation()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            startCompletionAnimation()
        }
    }

    private func startCompletionAnimation() {
        guard !isCompleting, !isDismissing else { return }

        cancelEdit()
        performCompletionFeedback()

        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
            isCompleting = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDismissing = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.18)) {
                onComplete()
            }
        }
    }

    private func performCompletionFeedback() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }

    private var rowOpacity: Double {
        if isDismissing { return 0 }
        if isDragging { return 0.4 }
        return 1
    }
}

private struct TodoRowDropDelegate: DropDelegate {
    let item: TodoItem
    @Binding var draggedItemID: UUID?
    let move: (UUID, UUID) -> Void
    let finish: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedItemID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItemID,
              draggedItemID != item.id else {
            return
        }

        move(draggedItemID, item.id)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        finish()
        return true
    }
}

private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 3
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit * 2),
                y: 0
            )
        )
    }
}
