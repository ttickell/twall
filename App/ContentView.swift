import SwiftUI
import TwallCore

struct ContentView: View {
    @Environment(AppState.self) private var state

    private var filteredMessages: [LabeledMessage] {
        if let num = state.selectedNumber {
            state.messages.filter { $0.message.to == num || $0.label == num }
        } else {
            state.messages
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            messageList
        } detail: {
            messageDetail
        }
        .task { await state.setup() }
        .toolbar { toolbarContent }
        .alert("Error", isPresented: Binding<Bool>(
            get: { state.error != nil },
            set: { if !$0 { state.error = nil } }
        )) {
            Button("OK") { state.error = nil }
        } message: {
            Text(state.error ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button(action: { Task { await state.refresh() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(state.isRefreshing)
        }
        ToolbarItem {
            Button(action: { state.markAllRead() }) {
                Label("Mark All Read", systemImage: "checkmark.circle")
            }
            .disabled(state.unreadSIDs.isEmpty)
        }
        ToolbarItem {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        List(selection: Binding<Set<String>>(
            get: { Set([state.selectedNumber ?? "all"]) },
            set: { state.selectedNumber = $0.first == "all" ? nil : $0.first }
        )) {
            Text("All Numbers").tag("all")
                .badge(state.unreadSIDs.count)

            Section("Numbers") {
                ForEach(state.numbers, id: \.0.phoneNumber) { num, label in
                    HStack {
                        Text(label).lineLimit(1)
                        Spacer()
                        let count = state.messages.filter { $0.message.to == num.phoneNumber }.count
                        Text("\(count)").foregroundStyle(.secondary)
                    }
                    .tag(num.phoneNumber)
                }
            }
        }
        .frame(minWidth: 200)
    }

    @ViewBuilder
    private var messageList: some View {
        List(selection: Binding<Set<String>>(
            get: { Set(state.selectedMessage.map { [$0.message.sid] } ?? []) },
            set: { sids in
                if let first = sids.first {
                    state.selectedMessage = filteredMessages.first { $0.message.sid == first }
                }
                if let msg = state.selectedMessage { state.markRead(msg) }
            }
        )) {
            ForEach(filteredMessages, id: \.message.sid) { msg in
                MessageRow(message: msg, isUnread: state.unreadSIDs.contains(msg.message.sid))
            }
        }
        .overlay {
            if filteredMessages.isEmpty && !state.isRefreshing {
                ContentUnavailableView("No Messages", systemImage: "message")
            }
            if state.isRefreshing && filteredMessages.isEmpty {
                ProgressView()
            }
        }
        .refreshable { await state.refresh() }
        .frame(minWidth: 300)
    }

    @ViewBuilder
    private var messageDetail: some View {
        if let msg = state.selectedMessage {
            MessageDetailView(message: msg)
        } else {
            ContentUnavailableView("Select a message", systemImage: "message")
        }
    }
}

struct MessageRow: View {
    let message: LabeledMessage
    let isUnread: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isUnread ? .blue : .clear)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.label).fontWeight(isUnread ? .semibold : .regular)
                    Spacer()
                    Text(message.message.dateSent, style: .offset)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Text(message.message.from)
                    .font(.caption).foregroundStyle(.secondary)
                Text(message.message.body).lineLimit(2).font(.callout)
            }
        }
        .padding(.vertical, 4)
    }
}
