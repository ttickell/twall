import SwiftUI
import TwallCore

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var sid: String = ""
    @State private var token: String = ""
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
        .onAppear { load() }
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
                Button("Save to Keychain") { save() }
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

    private func load() {
        sid = (try? KeychainStore.read(account: "TWILIO_ACCOUNT_SID")) ?? ""
        token = (try? KeychainStore.read(account: "TWILIO_AUTH_TOKEN")) ?? ""
    }

    private func save() {
        saveError = nil
        saved = false
        do {
            try KeychainStore.save(account: "TWILIO_ACCOUNT_SID", value: sid)
            try KeychainStore.save(account: "TWILIO_AUTH_TOKEN", value: token)
            saved = true
            Task { await state.setup() }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
