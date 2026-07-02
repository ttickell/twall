import Observation
import AppKit
import UserNotifications
import TwallCore

@MainActor @Observable
final class AppState {
    var messages: [LabeledMessage] = []
    var numbers: [(TwilioPhoneNumber, String)] = []
    var isRefreshing = false
    var selectedNumber: String?
    var selectedMessage: LabeledMessage?
    var error: String?
    var unreadSIDs: Set<String> = []

    private var store: MessageStore?
    private var refreshTimer: Timer?
    private let unreadStore = UnreadStore()
    private var notifiedSIDs: Set<String> = []

    static var hasCredentials: Bool { Config.hasCredentials() }

    func setup() async {
        do {
            let config = try Config.load()
            let client = TwilioClient(accountSID: config.accountSID, authToken: config.authToken)
            store = MessageStore(client: client, labels: config.labels)
            try await refresh()
            startAutoRefresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        guard let store, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let (sms, nums) = try await (store.fetchAllInbound(), store.fetchAllNumbers())

            let oldSIDs = Set(messages.map(\.message.sid))
            let newSIDs = Set(sms.map(\.message.sid))
            let freshlyArrived = newSIDs.subtracting(oldSIDs)

            if !freshlyArrived.isEmpty {
                let googleArrivals = sms.filter { freshlyArrived.contains($0.message.sid) && $0.isGoogle }
                for msg in googleArrivals {
                    sendNotification(for: msg)
                }
            }

            messages = sms
            numbers = nums
            unreadSIDs = unreadStore.load().intersection(newSIDs)
            updateBadge()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markRead(_ msg: LabeledMessage) {
        unreadSIDs.remove(msg.message.sid)
        unreadStore.save(unreadSIDs)
        updateBadge()
    }

    func markAllRead() {
        unreadSIDs = []
        unreadStore.save(unreadSIDs)
        updateBadge()
    }

    private func startAutoRefresh(interval: TimeInterval = 30) {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
    }

    private func updateBadge() {
        NSApp.dockTile.badgeLabel = unreadSIDs.isEmpty ? nil : "\(unreadSIDs.count)"
    }

    private func sendNotification(for msg: LabeledMessage) {
        guard !notifiedSIDs.contains(msg.message.sid) else { return }
        notifiedSIDs.insert(msg.message.sid)

        let content = UNMutableNotificationContent()
        content.title = "Google verification code"
        content.body = msg.message.body
        content.userInfo = ["sid": msg.message.sid]

        let request = UNNotificationRequest(
            identifier: msg.message.sid,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
