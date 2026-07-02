import ArgumentParser
import Foundation
import TwallCore

@main
struct Twall: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "twall",
        abstract: "View SMS messages from all your Twilio numbers.",
        subcommands: [List.self, Latest.self, Numbers.self, Label.self],
        defaultSubcommand: List.self
    )
}

// MARK: - Options

struct CommonOptions: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false

    @Option(name: .shortAndLong, help: "Filter by destination number label or E.164 number")
    var number: String?

    @Option(name: .shortAndLong, help: "Maximum messages to show")
    var limit: Int?
}

struct SinceOption: ParsableArguments {
    @Option(name: .shortAndLong, help: "Show only messages more recent than this (e.g. 1h, 30m, 24h)")
    var since: String?
}

// MARK: - Subcommands

extension Twall {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all inbound SMS messages across all numbers."
        )

        @OptionGroup var common: CommonOptions
        @OptionGroup var sinceOpt: SinceOption

        func run() throws {
            let config = try Config.load()
            let client = TwilioClient(accountSID: config.accountSID, authToken: config.authToken)
            let store = MessageStore(client: client, labels: config.labels)

            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    var messages = try await store.fetchAllInbound()

                    if let numberFilter = common.number {
                        messages = messages.filter { $0.label == numberFilter || $0.message.to == numberFilter }
                    }

                    if let sinceVal = sinceOpt.since, let sinceDate = parseSince(sinceVal) {
                        messages = messages.filter { $0.message.dateSent > sinceDate }
                    }

                    if let limit = common.limit, limit < messages.count {
                        messages = Array(messages.prefix(limit))
                    }

                    if common.json {
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        encoder.dateEncodingStrategy = .iso8601
                        let data = try encoder.encode(messages.map(MessageJSON.init))
                        print(String(data: data, encoding: .utf8)!)
                    } else {
                        renderTable(messages)
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                    Twall.exit(withError: ExitCode.failure)
                }
                semaphore.signal()
            }
            semaphore.wait()
        }
    }

    struct Latest: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show the most recent message per number."
        )

        @OptionGroup var common: CommonOptions

        func run() throws {
            let config = try Config.load()
            let client = TwilioClient(accountSID: config.accountSID, authToken: config.authToken)
            let store = MessageStore(client: client, labels: config.labels)

            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    var messages = try await store.fetchLatestPerNumber()

                    if let numberFilter = common.number {
                        messages = messages.filter { $0.label == numberFilter || $0.message.to == numberFilter }
                    }

                    if let limit = common.limit, limit < messages.count {
                        messages = Array(messages.prefix(limit))
                    }

                    if common.json {
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        encoder.dateEncodingStrategy = .iso8601
                        let data = try encoder.encode(messages.map(MessageJSON.init))
                        print(String(data: data, encoding: .utf8)!)
                    } else {
                        renderTable(messages)
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                    Twall.exit(withError: ExitCode.failure)
                }
                semaphore.signal()
            }
            semaphore.wait()
        }
    }

    struct Numbers: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all Twilio phone numbers and their labels."
        )

        @Flag(name: .shortAndLong, help: "Output as JSON")
        var json: Bool = false

        func run() throws {
            let config = try Config.load()
            let client = TwilioClient(accountSID: config.accountSID, authToken: config.authToken)
            let store = MessageStore(client: client, labels: config.labels)

            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    let numbers = try await store.fetchAllNumbers()

                    if json {
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        let data = try encoder.encode(numbers.map { n in
                            NumberJSON(
                                number: n.number.phoneNumber,
                                friendlyName: n.number.friendlyName,
                                label: n.label
                            )
                        })
                        print(String(data: data, encoding: .utf8)!)
                    } else {
                        print("Numbers (\(numbers.count)):")
                        print(String(repeating: "-", count: 60))
                        for (num, label) in numbers {
                            print(num.phoneNumber)
                            print("  Label: \(label)")
                            if !num.friendlyName.isEmpty {
                                print("  Friendly: \(num.friendlyName)")
                            }
                            print()
                        }
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                    Twall.exit(withError: ExitCode.failure)
                }
                semaphore.signal()
            }
            semaphore.wait()
        }
    }
}

// MARK: - Label subcommand

extension Twall {
    struct Label: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Manage number-to-account label mappings.",
            subcommands: [Set.self, Remove.self, List.self]
        )
    }
}

extension Twall.Label {
    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Set a label for a phone number.")

        @Argument(help: "E.164 phone number (e.g. +14155550101)")
        var number: String

        @Argument(help: "Label (e.g. email address)")
        var label: String

        func run() throws {
            var labels = try Config.loadLabels()
            labels[number] = label
            try Config.saveLabels(labels)
            print("\(number) → \(label)")
        }
    }

    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Remove a label for a phone number.")

        @Argument(help: "E.164 phone number")
        var number: String

        func run() throws {
            var labels = try Config.loadLabels()
            guard labels.removeValue(forKey: number) != nil else {
                print("No label found for \(number)")
                Twall.exit(withError: ExitCode.failure)
            }
            try Config.saveLabels(labels)
            print("Removed label for \(number)")
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show all label mappings.")

        @Flag(name: .shortAndLong, help: "Output as JSON")
        var json: Bool = false

        func run() throws {
            let labels = try Config.loadLabels()
            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(labels)
                print(String(data: data, encoding: .utf8)!)
            } else {
                if labels.isEmpty {
                    print("No labels configured.")
                    return
                }
                for (number, label) in labels.sorted(by: { $0.key < $1.key }) {
                    print("\(number)  →  \(label)")
                }
            }
        }
    }
}

// MARK: - Helpers

struct MessageJSON: Codable {
    let time: String
    let account: String
    let from: String
    let message: String
    let isGoogle: Bool

    init(_ lm: LabeledMessage) {
        let formatter = ISO8601DateFormatter()
        self.time = formatter.string(from: lm.message.dateSent)
        self.account = lm.label
        self.from = lm.message.from
        self.message = lm.message.body
        self.isGoogle = lm.isGoogle
    }
}

struct NumberJSON: Codable {
    let number: String
    let friendlyName: String
    let label: String
}

func renderTable(_ messages: [LabeledMessage]) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    let accountWidth = messages.map(\.label.count).max().map { min($0, 32) } ?? 10
    let fromWidth = messages.map(\.message.from.count).max().map { min($0, 16) } ?? 12

    for msg in messages {
        let time = formatter.string(from: msg.message.dateSent)
        let account = msg.label.bytelenTruncating(to: accountWidth).padding(toLength: accountWidth, withPad: " ", startingAt: 0)
        let from = msg.message.from.bytelenTruncating(to: fromWidth).padding(toLength: fromWidth, withPad: " ", startingAt: 0)
        let body = msg.message.body
            .replacingOccurrences(of: "\n", with: "\\n")
            .bytelenTruncating(to: 80)
        let googleTag = msg.isGoogle ? " [Google]" : ""
        print("\(time)  \(account)  \(from)  \(body)\(googleTag)")
    }

    if messages.isEmpty {
        print("(no messages found)")
    }
}

func parseSince(_ raw: String) -> Date? {
    let trimmed = raw.trimmingCharacters(in: .whitespaces).lowercased()
    let value: Double
    if trimmed.hasSuffix("h"), let v = Double(trimmed.dropLast()) {
        value = v * 3600
    } else if trimmed.hasSuffix("m"), let v = Double(trimmed.dropLast()) {
        value = v * 60
    } else if trimmed.hasSuffix("s"), let v = Double(trimmed.dropLast()) {
        value = v
    } else {
        return nil
    }
    return Date().addingTimeInterval(-value)
}

extension String {
    func bytelenTruncating(to maxLen: Int) -> String {
        guard count > maxLen else { return self }
        return String(prefix(maxLen - 1)) + "…"
    }
}
