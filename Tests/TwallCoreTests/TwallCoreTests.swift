import Foundation
import Testing
@testable import TwallCore

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseProvider: ((URL) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let provider = Self.responseProvider else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (data, response) = try provider(request.url!)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Serialized suite to avoid static mock contention

@Suite(.serialized)
struct TwallCoreTests {

    @Test("inbound messages are kept, outbound filtered")
    func inboundFiltering() async throws {
        let store = makeStore(
            numbersResponse: numberJSON(["+14155550101"]),
            messagesResponse: msgJSON([
                msg(sid: "SM1", direction: "inbound"),
                msg(sid: "SM2", direction: "outbound-api"),
                msg(sid: "SM3", direction: "inbound"),
            ])
        )
        let results = try await store.fetchAllInbound()
        #expect(results.count == 2)
    }

    @Test("labels are applied by phone number")
    func labeling() async throws {
        let store = makeStore(
            numbersResponse: numberJSON(["+14155550101"]),
            messagesResponse: msgJSON([
                msg(sid: "SM1", direction: "inbound", to: "+14155550101"),
            ]),
            labels: ["+14155550101": "myaccount@gmail.com"]
        )
        let results = try await store.fetchAllInbound()
        #expect(results.count == 1)
        #expect(results[0].label == "myaccount@gmail.com")
    }

    @Test("unlabeled numbers show raw E.164")
    func unlabeled() async throws {
        let store = makeStore(
            numbersResponse: numberJSON(["+14155550101"]),
            messagesResponse: msgJSON([
                msg(sid: "SM1", direction: "inbound", to: "+14155550101"),
            ])
        )
        let results = try await store.fetchAllInbound()
        #expect(results[0].label == "+14155550101")
    }

    @Test("latest returns newest inbound per number")
    func latestPerNumber() async throws {
        let store = makeStore(
            numbersResponse: numberJSON(["+14155550101"]),
            messagesResponse: msgJSON([
                msg(sid: "SM-latest", direction: "inbound", to: "+14155550101"),
            ])
        )
        let results = try await store.fetchLatestPerNumber()
        #expect(results.count == 1)
        #expect(results[0].message.sid == "SM-latest")
    }

    @Test("messages sorted newest first")
    func sortOrder() async throws {
        let store = makeStore(
            numbersResponse: numberJSON(["+14155550101"]),
            messagesResponse: msgJSON([
                msg(sid: "SM-old", dateSent: "Mon, 01 Jan 2024 12:00:00 +0000"),
                msg(sid: "SM-new", dateSent: "Tue, 02 Jan 2024 12:00:00 +0000"),
            ])
        )
        let results = try await store.fetchAllInbound()
        #expect(results.count == 2)
        #expect(results[0].message.sid == "SM-new")
        #expect(results[1].message.sid == "SM-old")
    }
}

// MARK: - Test Helpers

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeStore(
    numbersResponse: String,
    messagesResponse: String,
    labels: [String: String] = [:]
) -> MessageStore {
    let session = makeSession()

    MockURLProtocol.responseProvider = { url in
        if url.absoluteString.contains("IncomingPhoneNumbers") {
            let data = numbersResponse.data(using: .utf8)!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        } else if url.absoluteString.contains("Messages") {
            let data = messagesResponse.data(using: .utf8)!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
        throw URLError(.fileDoesNotExist)
    }

    let client = TwilioClient(accountSID: "ACtest", authToken: "test", session: session)
    return MessageStore(client: client, labels: labels)
}

private func numberJSON(_ numbers: [String]) -> String {
    let items = numbers.map { """
        { "sid": "PN\($0.suffix(6))", "phone_number": "\($0)", "friendly_name": "" }
        """ }.joined(separator: ",\n")
    return "{ \"incoming_phone_numbers\": [\n\(items)\n] }"
}

private func msgJSON(_ messages: [String]) -> String {
    "{ \"messages\": [\n\(messages.joined(separator: ",\n"))\n] }"
}

private func msg(
    sid: String = "SM1",
    direction: String = "inbound",
    from: String = "+12025551234",
    to: String = "+14155550101",
    body: String = "Hello",
    dateSent: String = "Thu, 19 Jan 2025 14:30:00 +0000",
    status: String = "received"
) -> String {
    """
    {
        "sid": "\(sid)",
        "from": "\(from)",
        "to": "\(to)",
        "direction": "\(direction)",
        "body": "\(body)",
        "date_sent": "\(dateSent)",
        "status": "\(status)"
    }
    """
}
