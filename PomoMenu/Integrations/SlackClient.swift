import Foundation

protocol SlackClient: Sendable {
    func setStatus(text: String, emoji: String, expiration: Int) async throws
    func clearStatus() async throws
    func setSnooze(minutes: Int) async throws
    func endSnooze() async throws
    func testConnection() async throws -> String
}

enum SlackError: Error, Equatable {
    case noToken
    case http(Int)
    case api(String)
    case transport
}

struct NoopSlackClient: SlackClient {
    func setStatus(text: String, emoji: String, expiration: Int) async throws {}
    func clearStatus() async throws {}
    func setSnooze(minutes: Int) async throws {}
    func endSnooze() async throws {}
    func testConnection() async throws -> String { "noop" }
}
