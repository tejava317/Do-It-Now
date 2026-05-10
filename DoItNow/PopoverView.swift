import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var focusMode: FocusModeController

    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool

    private let listHeight: CGFloat = 150

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
                    ForEach(store.items) { item in
                        TodoRow(item: item) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.complete(id: item.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: listHeight)
        }
    }

    private var input: some View {
        TextField("Add a task", text: $inputText)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($inputFocused)
            .onSubmit(addCurrentText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    private func addCurrentText() {
        let text = inputText
        inputText = ""
        withAnimation(.easeOut(duration: 0.2)) {
            store.add(text)
        }
        inputFocused = true
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
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                store.completeAll()
            }
        } label: {
            Text("Complete All")
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.items.isEmpty ? Color.secondary : Color.blue)
        .disabled(store.items.isEmpty)
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let onComplete: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onComplete) {
                Image(systemName: isHovered ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 13))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
