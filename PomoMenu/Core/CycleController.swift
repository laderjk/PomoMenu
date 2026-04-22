import Foundation

struct CycleState: Equatable, Sendable {
    var completedRegularPomosInCycle: Int
    var lastCompletedWasDeepFocus: Bool

    static let initial = CycleState(completedRegularPomosInCycle: 0, lastCompletedWasDeepFocus: false)
}

struct PlannedPhase: Equatable, Sendable {
    var type: SessionType
    var duration: TimeInterval
    var isDeepFocusBreak: Bool
    var countsTowardCycle: Bool
}

struct CycleController: Sendable {
    func updatedState(after completed: SessionType, state: CycleState, settings: AppSettingsProvider) -> CycleState {
        var next = state
        switch completed {
        case .regularFocus:
            next.completedRegularPomosInCycle = state.completedRegularPomosInCycle + 1
            next.lastCompletedWasDeepFocus = false
        case .deepFocus:
            if settings.countDeepFocusTowardCycle {
                next.completedRegularPomosInCycle = state.completedRegularPomosInCycle + 1
            }
            next.lastCompletedWasDeepFocus = true
        case .shortBreak:
            next.lastCompletedWasDeepFocus = false
        case .longBreak:
            next.completedRegularPomosInCycle = 0
            next.lastCompletedWasDeepFocus = false
        }
        return next
    }

    func nextPhase(after completed: SessionType, newState: CycleState, settings: AppSettingsProvider) -> PlannedPhase {
        switch completed {
        case .regularFocus:
            if newState.completedRegularPomosInCycle >= settings.pomosPerCycle {
                return PlannedPhase(
                    type: .longBreak,
                    duration: TimeInterval(settings.longBreakMinutes * 60),
                    isDeepFocusBreak: false,
                    countsTowardCycle: false
                )
            }
            return PlannedPhase(
                type: .shortBreak,
                duration: TimeInterval(settings.shortBreakMinutes * 60),
                isDeepFocusBreak: false,
                countsTowardCycle: false
            )

        case .deepFocus:
            return PlannedPhase(
                type: .shortBreak,
                duration: TimeInterval(settings.deepFocusBreakMinutes * 60),
                isDeepFocusBreak: true,
                countsTowardCycle: false
            )

        case .shortBreak, .longBreak:
            return PlannedPhase(
                type: .regularFocus,
                duration: TimeInterval(settings.regularFocusMinutes * 60),
                isDeepFocusBreak: false,
                countsTowardCycle: true
            )
        }
    }
}
