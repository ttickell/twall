import Foundation

public actor TwilioClient {
    private let session: URLSession
    private let baseURL = "https://api.twilio.com/2010-04-01"
    private let accountSID: String
    private let authToken: String

    private var authHeader: String {
        "\(accountSID):\(authToken)"
            .data(using: .utf8)!
            .base64EncodedString()
    }

    public init(accountSID: String, authToken: String, session: URLSession = .shared) {
        self.accountSID = accountSID
        self.authToken = authToken
        self.session = session
    }

    public func fetchPhoneNumbers() async throws -> [TwilioPhoneNumber] {
        let url = URL(string: "\(baseURL)/Accounts/\(accountSID)/IncomingPhoneNumbers.json")!
        let data = try await get(url)
        let response = try JSONDecoder().decode(PhoneNumbersResponse.self, from: data)
        return response.incomingPhoneNumbers
    }

    public func fetchMessages(to: String, pageSize: Int = 100) async throws -> [TwilioMessage] {
        var components = URLComponents(string: "\(baseURL)/Accounts/\(accountSID)/Messages.json")!
        components.queryItems = [
            URLQueryItem(name: "To", value: to),
            URLQueryItem(name: "PageSize", value: "\(pageSize)"),
        ]
        let url = components.url!
        let data = try await get(url)
        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)
        return response.messages
    }

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(authHeader)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TwilioError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw TwilioError.httpError(statusCode: http.statusCode, body: body)
        }
        return data
    }
}

public enum TwilioError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Twilio"
        case .httpError(let code, let body):
            return "Twilio HTTP \(code): \(body)"
        }
    }
}
