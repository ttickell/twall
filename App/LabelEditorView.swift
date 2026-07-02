import SwiftUI
import TwallCore

struct LabelEditorView: View {
    @State private var labels: [String: String] = [:]
    @State private var newNumber = ""
    @State private var newLabel = ""

    var body: some View {
        VStack(spacing: 0) {
            if labels.isEmpty {
                Spacer()
                ContentUnavailableView("No Labels", systemImage: "tag", description: Text("Add a number and email below."))
                Spacer()
            } else {
                List {
                    ForEach(Array(labels.keys.sorted()), id: \.self) { number in
                        HStack {
                            Text(number)
                                .font(.caption.monospaced())
                                .frame(width: 160, alignment: .leading)
                            TextField("Label", text: Binding(
                                get: { labels[number] ?? "" },
                                set: { labels[number] = $0; persist() }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    .onDelete { offsets in
                        let keys = labels.keys.sorted()
                        for i in offsets { labels.removeValue(forKey: keys[i]) }
                        persist()
                    }
                }
            }

            Divider()

            HStack {
                TextField("+14155550101", text: $newNumber)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
                TextField("email@example.com", text: $newLabel)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    guard !newNumber.isEmpty, !newLabel.isEmpty else { return }
                    labels[newNumber] = newLabel
                    newNumber = ""
                    newLabel = ""
                    persist()
                }
                .disabled(newNumber.isEmpty || newLabel.isEmpty)
            }
        }
        .onAppear { load() }
    }

    private func load() {
        labels = (try? Config.loadLabels()) ?? [:]
    }

    private func persist() {
        try? Config.saveLabels(labels)
    }
}
