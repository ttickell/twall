import SwiftUI
import TwallCore

struct MessageDetailView: View {
    let message: LabeledMessage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if message.isGoogle {
                        Label("Google", systemImage: "g.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .clipShape(.capsule)
                    }
                    Spacer()
                    Text(message.message.dateSent, style: .date)
                        .foregroundStyle(.secondary)
                    Text(message.message.dateSent, style: .time)
                        .foregroundStyle(.secondary)
                }

                GroupBox("Details") {
                    DetailRow(label: "Account", value: message.label)
                    DetailRow(label: "From", value: message.message.from)
                    DetailRow(label: "To", value: message.message.to)
                    DetailRow(label: "Status", value: message.message.status)
                }

                GroupBox("Message") {
                    Text(message.message.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
    }
}
