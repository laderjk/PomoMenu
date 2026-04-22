import Foundation

enum SessionStatus: String, Codable, Sendable {
    case completed
    case skipped
}

struct Session: Equatable, Sendable {
    var type: SessionType
    var plannedDuration: TimeInterval
    var startedAt: Date
    var endedAt: Date?
    var status: SessionStatus?
    var task: String?
    var countsTowardCycle: Bool

    init(
        type: SessionType,
        plannedDuration: TimeInterval,
        startedAt: Date,
        endedAt: Date? = nil,
        status: SessionStatus? = nil,
        task: String? = nil,
        countsTowardCycle: Bool = true
    ) {
        self.type = type
        self.plannedDuration = plannedDuration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.task = task
        self.countsTowardCycle = countsTowardCycle
    }
}

struct DailyStats: Equatable, Sendable {
    var pomosCompleted: Int
    var deepFocusCompleted: Int
    var totalFocusedMinutes: Int

    static let empty = DailyStats(pomosCompleted: 0, deepFocusCompleted: 0, totalFocusedMinutes: 0)
}
