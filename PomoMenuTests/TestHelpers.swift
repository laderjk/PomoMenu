import Foundation
@testable import PomoMenu

final class MockClock: TimerClock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    init(_ initial: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self._now = initial
    }

    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return _now
    }

    func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _now = _now.addingTimeInterval(seconds)
    }

    func set(_ date: Date) {
        lock.lock(); defer { lock.unlock() }
        _now = date
    }
}

final class InMemoryStatsStore: StatsCSVStoreProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var appended: [Session] = []
    let fileURL: URL = URL(fileURLWithPath: "/tmp/nonexistent.csv")

    func append(session: Session) throws {
        lock.lock(); defer { lock.unlock() }
        appended.append(session)
    }

    func dailyStats(for date: Date) throws -> DailyStats {
        lock.lock(); defer { lock.unlock() }
        let cal = Calendar(identifier: .gregorian)
        let day = cal.dateComponents([.year, .month, .day], from: date)
        var pomos = 0, deeps = 0, minutes = 0
        for session in appended {
            guard session.status == .completed else { continue }
            let sday = cal.dateComponents([.year, .month, .day], from: session.startedAt)
            guard sday == day else { continue }
            let mins = Int(((session.endedAt ?? session.startedAt).timeIntervalSince(session.startedAt) / 60).rounded())
            switch session.type {
            case .regularFocus: pomos += 1; minutes += mins
            case .deepFocus:    deeps += 1; minutes += mins
            default: break
            }
        }
        return DailyStats(pomosCompleted: pomos, deepFocusCompleted: deeps, totalFocusedMinutes: minutes)
    }
}

final class CapturingSlackClient: SlackClient, @unchecked Sendable {
    struct Event: Equatable {
        enum Kind: Equatable { case setStatus, clearStatus, setSnooze, endSnooze, test }
        let kind: Kind
        let text: String?
        let emoji: String?
        let expiration: Int?
        let minutes: Int?
    }

    private let lock = NSLock()
    private(set) var events: [Event] = []

    func setStatus(text: String, emoji: String, expiration: Int) async throws {
        lock.lock(); defer { lock.unlock() }
        events.append(.init(kind: .setStatus, text: text, emoji: emoji, expiration: expiration, minutes: nil))
    }
    func clearStatus() async throws {
        lock.lock(); defer { lock.unlock() }
        events.append(.init(kind: .clearStatus, text: nil, emoji: nil, expiration: nil, minutes: nil))
    }
    func setSnooze(minutes: Int) async throws {
        lock.lock(); defer { lock.unlock() }
        events.append(.init(kind: .setSnooze, text: nil, emoji: nil, expiration: nil, minutes: minutes))
    }
    func endSnooze() async throws {
        lock.lock(); defer { lock.unlock() }
        events.append(.init(kind: .endSnooze, text: nil, emoji: nil, expiration: nil, minutes: nil))
    }
    func testConnection() async throws -> String {
        lock.lock(); defer { lock.unlock() }
        events.append(.init(kind: .test, text: nil, emoji: nil, expiration: nil, minutes: nil))
        return "test-user"
    }
}

final class MutableSettings: AppSettingsProvider, @unchecked Sendable {
    var regularFocusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var deepFocusMinutes: Int = 50
    var deepFocusBreakMinutes: Int = 15
    var longBreakMinutes: Int = 15
    var pomosPerCycle: Int = 4
    var countDeepFocusTowardCycle: Bool = false
    var autoStartNextPhase: Bool = true
    var playSoundOnPhaseEnd: Bool = false
    var slackEnabled: Bool = false
    var slackSyncEveryPhase: Bool = false
    var slackDNDDeepFocusOnly: Bool = true
    var promptTaskNameOnStart: Bool = false
    var menuBarTimeFormat: MenuBarTimeFormat = .mmss

    func emoji(for type: SessionType) -> String { type.defaultEmoji }
    func slackEmoji(for type: SessionType) -> String { type.slackEmojiDefault }
}

final class CapturingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var requests: [URLRequest] = []
    var responseData: Data = Data("{\"ok\":true}".utf8)
    var statusCode: Int = 200

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        lock.lock(); requests.append(request); lock.unlock()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}
