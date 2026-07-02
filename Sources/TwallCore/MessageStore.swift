import Foundation

public struct MessageStore: Sendable {
    private let client: TwilioClient
    private let labels: [String: String]

    public init(client: TwilioClient, labels: [String: String]) {
        self.client = client
        self.labels = labels
    }

    public func fetchAllInbound() async throws -> [LabeledMessage] {
        let numbers = try await client.fetchPhoneNumbers()
        let e164numbers = Set(numbers.map { $0.phoneNumber })

        var allMessages: [TwilioMessage] = []
        for number in e164numbers {
            let msgs = try await client.fetchMessages(to: number, pageSize: 100)
            allMessages.append(contentsOf: msgs)
        }

        let inbound = allMessages.filter { $0.direction == "inbound" }

        return inbound.map { msg in
            let label = labels[msg.to] ?? msg.to
            return LabeledMessage(message: msg, label: label, isGoogle: isGoogleMessage(msg))
        }.sorted { $0.message.dateSent > $1.message.dateSent }
    }

    public func fetchLatestPerNumber() async throws -> [LabeledMessage] {
        let numbers = try await client.fetchPhoneNumbers()
        let e164numbers = numbers.map { $0.phoneNumber }

        var latest: [LabeledMessage] = []
        for number in e164numbers {
            let msgs = try await client.fetchMessages(to: number, pageSize: 1)
            if let msg = msgs.first(where: { $0.direction == "inbound" }) {
                let label = labels[msg.to] ?? msg.to
                latest.append(LabeledMessage(message: msg, label: label, isGoogle: isGoogleMessage(msg)))
            }
        }
        return latest.sorted { $0.message.dateSent > $1.message.dateSent }
    }

    public func fetchAllNumbers() async throws -> [(number: TwilioPhoneNumber, label: String)] {
        let numbers = try await client.fetchPhoneNumbers()
        return numbers.map { ($0, labels[$0.phoneNumber] ?? "(unlabeled)") }
    }

    private func isGoogleMessage(_ msg: TwilioMessage) -> Bool {
        if msg.from.localizedCaseInsensitiveContains("google") { return true }
        if msg.body.localizedCaseInsensitiveContains("google") { return true }
        if msg.body.localizedCaseInsensitiveContains("verification code") { return true }
        return false
    }
}
