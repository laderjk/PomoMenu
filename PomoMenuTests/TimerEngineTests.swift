import XCTest
@testable import PomoMenu

@MainActor
final class TimerEngineTests: XCTestCase {
    private var clock: MockClock!
    private var store: InMemoryStatsStore!
    private var slack: CapturingSlackClient!
    private var settings: MutableSettings!
    private var engine: TimerEngine!

    override func setUp() async throws {
        clock = MockClock()
        store = InMemoryStatsStore()
        slack = CapturingSlackClient()
        settings = MutableSettings()
        settings.autoStartNextPhase = false
        engine = TimerEngine(
            clock: clock,
            csvStore: store,
            slack: slack,
            sound: NoopSoundPlayer(),
            settings: settings,
            cycle: CycleController(),
            enableBackgroundTick: false
        )
    }

    func test_startRegularFocus_setsRemainingToConfiguredDuration() {
        settings.regularFocusMinutes = 25
        engine.startRegularFocus()
        XCTAssertEqual(engine.currentType, .regularFocus)
        XCTAssertTrue(engine.isRunning)
        XCTAssertEqual(engine.remainingSeconds, 25 * 60, accuracy: 0.001)
    }

    func test_pause_preservesRemainingTimeAcrossDelay() {
        settings.regularFocusMinutes = 1
        engine.startRegularFocus()
        clock.advance(by: 20)
        engine.tick()
        XCTAssertEqual(engine.remainingSeconds, 40, accuracy: 0.01)

        engine.pause()
        XCTAssertTrue(engine.isPaused)

        clock.advance(by: 300) // Long real-world pause.
        engine.tick() // Should not decrement while paused.
        XCTAssertEqual(engine.remainingSeconds, 40, accuracy: 0.01)

        engine.resume()
        XCTAssertFalse(engine.isPaused)
        clock.advance(by: 5)
        engine.tick()
        XCTAssertEqual(engine.remainingSeconds, 35, accuracy: 0.01)
    }

    func test_skip_logsSkippedAndAdvances() {
        settings.regularFocusMinutes = 25
        engine.startRegularFocus(task: "write spec")
        clock.advance(by: 60)
        engine.skip()
        XCTAssertEqual(store.appended.count, 1)
        XCTAssertEqual(store.appended.first?.status, .skipped)
        XCTAssertEqual(store.appended.first?.type, .regularFocus)
        XCTAssertEqual(store.appended.first?.task, "write spec")
        XCTAssertFalse(engine.isRunning)
        // Skipped focus does NOT advance the cycle counter.
        XCTAssertEqual(engine.cycleState.completedRegularPomosInCycle, 0)
        // Next planned phase is short break since it's treated as completed-in-sequence.
        XCTAssertEqual(engine.nextPlannedPhase?.type, .shortBreak)
    }

    func test_completingFourRegularPomosTriggersLongBreak() {
        settings.regularFocusMinutes = 1
        settings.shortBreakMinutes = 1
        settings.longBreakMinutes = 15
        settings.pomosPerCycle = 4

        for i in 1...4 {
            engine.startRegularFocus()
            clock.advance(by: 61)
            engine.tick()
            XCTAssertEqual(engine.todayStats.pomosCompleted, i, "after pomo \(i)")
        }

        XCTAssertEqual(engine.cycleState.completedRegularPomosInCycle, 4)
        XCTAssertEqual(engine.nextPlannedPhase?.type, .longBreak)
        XCTAssertEqual(engine.nextPlannedPhase?.duration, 15 * 60)
    }

    func test_deepFocusDoesNotAdvanceCycleByDefault() {
        settings.countDeepFocusTowardCycle = false
        settings.deepFocusMinutes = 1

        engine.startDeepFocus()
        clock.advance(by: 61)
        engine.tick()

        XCTAssertEqual(engine.cycleState.completedRegularPomosInCycle, 0)
        XCTAssertEqual(engine.nextPlannedPhase?.type, .shortBreak)
        XCTAssertEqual(engine.nextPlannedPhase?.isDeepFocusBreak, true)
        XCTAssertEqual(engine.nextPlannedPhase?.duration, TimeInterval(settings.deepFocusBreakMinutes * 60))
    }

    func test_deepFocusAdvancesCycleWhenToggled() {
        settings.countDeepFocusTowardCycle = true
        settings.deepFocusMinutes = 1

        engine.startDeepFocus()
        clock.advance(by: 61)
        engine.tick()

        XCTAssertEqual(engine.cycleState.completedRegularPomosInCycle, 1)
    }

    func test_autoStartNextPhaseStartsShortBreakAfterFocusCompletion() {
        settings.autoStartNextPhase = true
        settings.regularFocusMinutes = 1
        engine.startRegularFocus()
        clock.advance(by: 61)
        engine.tick()
        XCTAssertEqual(engine.currentType, .shortBreak)
        XCTAssertTrue(engine.isRunning)
    }

    func test_resetCycleClearsStateAndCycleCounter() {
        settings.regularFocusMinutes = 1
        engine.startRegularFocus()
        clock.advance(by: 61)
        engine.tick()
        engine.resetCycle()
        XCTAssertFalse(engine.isRunning)
        XCTAssertNil(engine.currentType)
        // Previous completion incremented the counter; reset clears.
        XCTAssertEqual(engine.cycleState.completedRegularPomosInCycle, 0)
    }

    func test_slackStatusSetOnDeepFocusStart() async {
        settings.slackEnabled = true
        settings.slackSyncEveryPhase = true
        settings.deepFocusMinutes = 1

        engine.startDeepFocus()
        // Let background task deliver.
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 5_000_000)
            if slack.events.count >= 2 { break }
        }
        let kinds = slack.events.map(\.kind)
        XCTAssertTrue(kinds.contains(.setStatus))
        XCTAssertTrue(kinds.contains(.setSnooze))
    }
}
