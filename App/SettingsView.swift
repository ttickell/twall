import SwiftUI
import TwallCore

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var sid = ""
    @State private var token = ""
    @State private var saveError: String?
    @State private var saved = false

    var body: some View {
        TabView {
            accountTab
                .tabItem { Label("Account", systemImage: "key.fill") }

            labelsTab
                .tabItem { Label("Labels", systemImage: "tag.fill") }
        }
        .frame(width: 460, height: 300)
        .onAppear { loadFromEnv() }
    }

    @ViewBuilder
    private var accountTab: some View {
        Form {
            SecureField("Account SID", text: $sid)
            SecureField("Auth Token", text: $token)

            HStack {
                if let err = saveError {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
                Spacer()
                if saved {
                    Text("Saved").foregroundStyle(.green)
                }
                Button("Save to .env") { save() }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var labelsTab: some View {
        LabelEditorView()
            .padding()
    }

    private func loadFromEnv() {
        let url = Config.envFileURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        for line in content.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("TWILIO_ACCOUNT_SID=") {
                sid = String(t.dropFirst("TWILIO_ACCOUNT_SID=".count))
            } else if t.hasPrefix("TWILIO_AUTH_TOKEN=") {
                token = String(t.dropFirst("TWILIO_AUTH_TOKEN=".count))
            }
        }
    }

    private func save() {
        saveError = nil
        saved = false
        do {
            try Config.saveCredentials(accountSID: sid, authToken: token)
            saved = true
            Task { await state.setup() }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
