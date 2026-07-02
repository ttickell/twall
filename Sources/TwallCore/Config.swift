import Foundation

public struct Config: Sendable {
    public let accountSID: String
    public let authToken: String
    public let labels: [String: String]

    private static let configDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/twall")
    }()

    public static func load() throws -> Config {
        var env = ProcessInfo.processInfo.environment

        let envFiles = [
            configDir.appendingPathComponent(".env"),
            URL(fileURLWithPath: ".env"),
        ]
        for url in envFiles {
            if FileManager.default.fileExists(atPath: url.path) {
                let content = try String(contentsOf: url, encoding: .utf8)
                for line in content.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                    let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        env[parts[0]] = parts[1]
                    }
                }
                break
            }
        }

        guard let sid = env["TWILIO_ACCOUNT_SID"], !sid.isEmpty else {
            throw ConfigError.missingSID
        }
        guard let token = env["TWILIO_AUTH_TOKEN"], !token.isEmpty else {
            throw ConfigError.missingToken
        }

        let labels = try loadLabels()

        return Config(accountSID: sid, authToken: token, labels: labels)
    }

    public static func labelsFileURL() -> URL {
        let urls = [
            configDir.appendingPathComponent("labels.json"),
            URL(fileURLWithPath: "labels.json"),
        ]
        for url in urls {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return configDir.appendingPathComponent("labels.json")
    }

    public static func loadLabels() throws -> [String: String] {
        let url = labelsFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    public static func saveLabels(_ labels: [String: String]) throws {
        let url = labelsFileURL()
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(labels)
        try data.write(to: url, options: .atomic)
    }

    public enum ConfigError: Error, LocalizedError {
        case missingSID
        case missingToken

        public var errorDescription: String? {
            switch self {
            case .missingSID:
                return "TWILIO_ACCOUNT_SID not found in .env or environment"
            case .missingToken:
                return "TWILIO_AUTH_TOKEN not found in .env or environment"
            }
        }
    }
}
