import XCTest
@testable import PomoMenu

final class CycleControllerTests: XCTestCase {
    private let cycle = CycleController()
    private var settings: MutableSettings!

    override func setUp() {
        settings = MutableSettings()
    }

    func test_updatedStateIncrementsPomosOnRegularCompletion() {
        let state = CycleState.initial
        let next = cycle.updatedState(after: .regularFocus, state: state, settings: settings)
        XCTAssertEqual(next.completedRegularPomosInCycle, 1)
        XCTAssertFalse(next.lastCompletedWasDeepFocus)
    }

    func test_nextPhaseAfterRegularIsShortBreakWhenBelowThreshold() {
        let state = CycleState(completedRegularPomosInCycle: 2, lastCompletedWasDeepFocus: false)
        let next = cycle.nextPhase(after: .regularFocus, newState: state, settings: settings)
        XCTAssertEqual(next.type, .shortBreak)
        XCTAssertEqual(next.duration, TimeInterval(settings.shortBreakMinutes * 60))
    }

    func test_nextPhaseAfterRegularIsLongBreakAtThreshold() {
        settings.pomosPerCycle = 4
        let state = CycleState(completedRegularPomosInCycle: 4, lastCompletedWasDeepFocus: false)
        let next = cycle.nextPhase(after: .regularFocus, newState: state, settings: settings)
        XCTAssertEqual(next.type, .longBreak)
    }

    func test_longBreakResetsCounter() {
        let state = CycleState(completedRegularPomosInCycle: 4, lastCompletedWasDeepFocus: false)
        let next = cycle.updatedState(after: .longBreak, state: state, settings: settings)
        XCTAssertEqual(next.completedRegularPomosInCycle, 0)
    }

    func test_deepFocusReturnsDeepFocusBreak() {
        let state = CycleState.initial
        let next = cycle.nextPhase(after: .deepFocus, newState: state, settings: settings)
        XCTAssertEqual(next.type, .shortBreak)
        XCTAssertTrue(next.isDeepFocusBreak)
        XCTAssertEqual(next.duration, TimeInterval(settings.deepFocusBreakMinutes * 60))
    }

    func test_deepFocusDoesNotAdvanceCounterByDefault() {
        settings.countDeepFocusTowardCycle = false
        let state = CycleState.initial
        let next = cycle.updatedState(after: .deepFocus, state: state, settings: settings)
        XCTAssertEqual(next.completedRegularPomosInCycle, 0)
        XCTAssertTrue(next.lastCompletedWasDeepFocus)
    }

    func test_deepFocusAdvancesCounterWhenEnabled() {
        settings.countDeepFocusTowardCycle = true
        let state = CycleState(completedRegularPomosInCycle: 1, lastCompletedWasDeepFocus: false)
        let next = cycle.updatedState(after: .deepFocus, state: state, settings: settings)
        XCTAssertEqual(next.completedRegularPomosInCycle, 2)
    }

    func test_breakAlwaysReturnsToRegularFocus() {
        let state = CycleState.initial
        XCTAssertEqual(
            cycle.nextPhase(after: .shortBreak, newState: state, settings: settings).type,
            .regularFocus
        )
        XCTAssertEqual(
            cycle.nextPhase(after: .longBreak, newState: state, settings: settings).type,
            .regularFocus
        )
    }
}
