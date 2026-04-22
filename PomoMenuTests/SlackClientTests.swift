import XCTest
@testable import PomoMenu

final class SlackClientTests: XCTestCase {
    private var transport: CapturingTransport!
    private var client: LiveSlackClient!

    override func setUp() {
        transport = CapturingTransport()
        client = LiveSlackClient(
            transport: transport,
            tokenProvider: { "xoxp-test-token" },
            baseURL: URL(string: "https://slack.example/api")!
        )
    }

    func test_setStatusSendsExpectedJSON() async throws {
        try await client.setStatus(text: "Focusing", emoji: ":tomato:", expiration: 123456)

        XCTAssertEqual(transport.requests.count, 1)
        let req = transport.requests[0]
        XCTAssertEqual(req.url?.absoluteString, "https://slack.example/api/users.profile.set")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer xoxp-test-token")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=utf-8")

        let body = try XCTUnwrap(req.httpBody)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let profile = try XCTUnwrap(obj["profile"] as? [String: Any])
        XCTAssertEqual(profile["status_text"] as? String, "Focusing")
        XCTAssertEqual(profile["status_emoji"] as? String, ":tomato:")
        XCTAssertEqual(profile["status_expiration"] as? Int, 123456)
    }

    func test_clearStatusSendsEmptyFields() async throws {
        try await client.clearStatus()
        let req = transport.requests[0]
        let body = try XCTUnwrap(req.httpBody)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let profile = try XCTUnwrap(obj["profile"] as? [String: Any])
        XCTAssertEqual(profile["status_text"] as? String, "")
        XCTAssertEqual(profile["status_emoji"] as? String, "")
        XCTAssertEqual(profile["status_expiration"] as? Int, 0)
    }

    func test_setSnoozeSendsNumMinutesQueryAndAuthHeader() async throws {
        try await client.setSnooze(minutes: 25)
        let req = transport.requests[0]
        XCTAssertEqual(req.httpMethod, "POST")
        let url = try XCTUnwrap(req.url)
        XCTAssertEqual(url.path, "/api/dnd.setSnooze")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "num_minutes" })?.value, "25")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer xoxp-test-token")
    }

    func test_endSnoozeHitsCorrectEndpoint() async throws {
        try await client.endSnooze()
        let req = transport.requests[0]
        XCTAssertEqual(req.url?.path, "/api/dnd.endSnooze")
        XCTAssertEqual(req.httpMethod, "POST")
    }

    func test_missingTokenThrows() async {
        client = LiveSlackClient(
            transport: transport,
            tokenProvider: { nil },
            baseURL: URL(string: "https://slack.example/api")!
        )
        do {
            try await client.setStatus(text: "x", emoji: ":x:", expiration: 0)
            XCTFail("expected SlackError.noToken")
        } catch let err as SlackError {
            XCTAssertEqual(err, .noToken)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_apiErrorPropagates() async {
        transport.responseData = Data("{\"ok\":false,\"error\":\"not_authed\"}".utf8)
        do {
            try await client.setStatus(text: "x", emoji: ":x:", expiration: 0)
            XCTFail("expected SlackError.api")
        } catch let err as SlackError {
            XCTAssertEqual(err, .api("not_authed"))
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
