import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var sid: String = ""
    @State private var token: String = ""
    @State private var saveError: String?
    @State private var saved = false
    @State private var showLabelEditor = false

    var body: some View {
        Form {
            Section("Twilio Credentials") {
                SecureField("Account SID", text: $sid)
                SecureField("Auth Token", text: $token)

                HStack {
                    if let err = saveError {
                        Text(err).foregroundStyle(.red)
                    }
                    Spacer()
                    if saved {
                        Text("Saved").foregroundStyle(.green)
                    }
                    Button("Save to Keychain") { save() }
                }
            }

            Section("Labels") {
                Button("Edit Labels...") { showLabelEditor = true }
                    .sheet(isPresented: $showLabelEditor) {
                        LabelEditorView()
                    }
            }

            Section("Actions") {
                Button("Refresh Now") {
                    Task { await state.refresh() }
                }
                Button("Mark All Read") {
                    state.markAllRead()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .onAppear { load() }
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
