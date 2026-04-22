import Foundation

protocol TimerClock: Sendable {
    func now() -> Date
}

struct SystemTimerClock: TimerClock {
    func now() -> Date { Date() }
}
