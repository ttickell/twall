import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var sid = ""
    @State private var token = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Welcome to Twall")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter your Twilio credentials to start viewing your SMS messages.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox {
                VStack(spacing: 12) {
                    SecureField("Account SID", text: $sid)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                    SecureField("Auth Token", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                }
                .padding(8)
            }

            if let err = errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save & Continue") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(sid.isEmpty || token.isEmpty || isSaving)
            }
        }
        .padding(24)
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        do {
            try KeychainStore.save(account: "TWILIO_ACCOUNT_SID", value: sid)
            try KeychainStore.save(account: "TWILIO_AUTH_TOKEN", value: token)
            Task {
                await state.setup()
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
