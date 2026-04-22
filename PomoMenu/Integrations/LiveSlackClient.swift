import Foundation

/// Injectable HTTP transport so the client is testable with captured URLRequests.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

struct LiveSlackClient: SlackClient {
    let transport: HTTPTransport
    let tokenProvider: @Sendable () -> String?
    let baseURL: URL

    init(
        transport: HTTPTransport = URLSessionTransport(),
        tokenProvider: @escaping @Sendable () -> String? = { KeychainStore.shared.slackToken() },
        baseURL: URL = URL(string: "https://slack.com/api")!
    ) {
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.baseURL = baseURL
    }

    func setStatus(text: String, emoji: String, expiration: Int) async throws {
        let body: [String: Any] = [
            "profile": [
                "status_text": text,
                "status_emoji": emoji,
                "status_expiration": expiration,
            ],
        ]
        _ = try await postJSON(path: "users.profile.set", body: body)
    }

    func clearStatus() async throws {
        let body: [String: Any] = [
            "profile": [
                "status_text": "",
                "status_emoji": "",
                "status_expiration": 0,
            ],
        ]
        _ = try await postJSON(path: "users.profile.set", body: body)
    }

    func setSnooze(minutes: Int) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("dnd.setSnooze"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "num_minutes", value: String(minutes))]
        guard let url = components?.url else { throw SlackError.transport }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        try applyAuth(&request)
        _ = try await send(request)
    }

    func endSnooze() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("dnd.endSnooze"))
        request.httpMethod = "POST"
        try applyAuth(&request)
        _ = try await send(request)
    }

    func testConnection() async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth.test"))
        request.httpMethod = "POST"
        try applyAuth(&request)
        let data = try await send(request)
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let user = obj["user"] as? String { return user }
            if let error = obj["error"] as? String { throw SlackError.api(error) }
        }
        return ""
    }

    // MARK: - Private

    private func postJSON(path: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        try applyAuth(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return try await send(request)
    }

    private func applyAuth(_ request: inout URLRequest) throws {
        guard let token = tokenProvider(), !token.isEmpty else { throw SlackError.noToken }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw SlackError.transport
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SlackError.http(http.statusCode)
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ok = obj["ok"] as? Bool, ok == false {
            let msg = (obj["error"] as? String) ?? "unknown"
            throw SlackError.api(msg)
        }
        return data
    }
}
