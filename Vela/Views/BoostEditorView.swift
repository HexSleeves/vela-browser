import SwiftUI

struct BoostEditorView: View {
    @Environment(BrowserStore.self) private var store
    @State private var editingBoost: Boost?
    @State private var isCreating = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Boosts")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    isCreating = true
                    editingBoost = Boost(hostPattern: "", css: "", js: "")
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if store.boosts.isEmpty && !isCreating {
                ContentUnavailableView {
                    Label("No Boosts", systemImage: "bolt")
                } description: {
                    Text("Customize websites with custom CSS and JavaScript.")
                } actions: {
                    Button("Create Boost") {
                        isCreating = true
                        editingBoost = Boost(hostPattern: "", css: "", js: "")
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.boosts) { boost in
                        boostRow(boost)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(item: $editingBoost) { boost in
            BoostFormView(boost: boost, isNew: isCreating) { saved in
                if isCreating {
                    store.addBoost(saved)
                } else {
                    store.updateBoost(saved)
                }
                isCreating = false
                editingBoost = nil
            } onCancel: {
                isCreating = false
                editingBoost = nil
            }
        }
    }

    private func boostRow(_ boost: Boost) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(boost.isEnabled ? .yellow : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(boost.hostPattern)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !boost.css.isEmpty {
                        Label("CSS", systemImage: "paintbrush")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    if !boost.js.isEmpty {
                        Label("JS", systemImage: "curlybraces")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { boost.isEnabled },
                set: { _ in store.toggleBoost(boost.id) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit…") {
                isCreating = false
                editingBoost = boost
            }
            Button("Delete", role: .destructive) {
                store.removeBoost(boost.id)
            }
        }
        .onTapGesture(count: 2) {
            isCreating = false
            editingBoost = boost
        }
    }
}

// MARK: - Boost Form

struct BoostFormView: View {
    @State var boost: Boost
    let isNew: Bool
    let onSave: (Boost) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(isNew ? "New Boost" : "Edit Boost")
                .font(.title3.weight(.semibold))

            Form {
                TextField("Host Pattern", text: $boost.hostPattern, prompt: Text("e.g. *.example.com"))
                    .textFieldStyle(.roundedBorder)
                    .help("Matches against the page host. Use * as wildcard.")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom CSS")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $boost.css)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                        .border(Color.secondary.opacity(0.3))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom JavaScript")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $boost.js)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                        .border(Color.secondary.opacity(0.3))
                }

                Toggle("Enabled", isOn: $boost.isEnabled)
            }
            .padding(.horizontal)

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isNew ? "Create" : "Save") {
                    guard !boost.hostPattern.isEmpty else { return }
                    onSave(boost)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(boost.hostPattern.isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 440)
        .padding()
    }
}
