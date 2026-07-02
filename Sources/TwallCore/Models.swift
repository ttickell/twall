import Foundation

public struct TwilioMessage: Codable, Sendable {
    public let sid: String
    public let from: String
    public let to: String
    public let direction: String
    public let body: String
    public let dateSent: Date
    public let status: String

    enum CodingKeys: String, CodingKey {
        case sid, from, to, direction, body, status
        case dateSent = "date_sent"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sid = try container.decode(String.self, forKey: .sid)
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        direction = try container.decode(String.self, forKey: .direction)
        body = try container.decode(String.self, forKey: .body)
        status = try container.decode(String.self, forKey: .status)
        let dateString = try container.decode(String.self, forKey: .dateSent)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .dateSent,
                in: container,
                debugDescription: "Invalid date format: \(dateString)"
            )
        }
        dateSent = date
    }
}

public struct TwilioPhoneNumber: Codable, Sendable {
    public let sid: String
    public let phoneNumber: String
    public let friendlyName: String

    enum CodingKeys: String, CodingKey {
        case sid
        case phoneNumber = "phone_number"
        case friendlyName = "friendly_name"
    }
}

public struct LabeledMessage: Sendable {
    public let message: TwilioMessage
    public let label: String
    public let isGoogle: Bool
}

struct MessagesResponse: Codable {
    let messages: [TwilioMessage]
}

struct PhoneNumbersResponse: Codable {
    let incomingPhoneNumbers: [TwilioPhoneNumber]

    enum CodingKeys: String, CodingKey {
        case incomingPhoneNumbers = "incoming_phone_numbers"
    }
}
