import Foundation
import SwiftUI
import Combine

@MainActor
final class TimerEngine: @preconcurrency ObservableObject {
    @Published private(set) var currentType: SessionType?
    @Published private(set) var phaseStartDate: Date?
    @Published private(set) var phaseEndDate: Date?
    @Published private(set) var phasePlannedDuration: TimeInterval = 0
    @Published private(set) var remainingSeconds: TimeInterval = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var cycleState: CycleState = .initial
    @Published private(set) var todayStats: DailyStats = .empty
    @Published private(set) var currentTask: String?
    @Published private(set) var nextPlannedPhase: PlannedPhase?
    @Published private(set) var isCurrentPhaseDeepFocusBreak: Bool = false
    @Published private(set) var slackHasError: Bool = false
    @Published private(set) var dndActive: Bool = false

    private let clock: any TimerClock
    private let csvStore: StatsCSVStoreProtocol
    private let slack: SlackClient
    private let sound: SoundPlayerProtocol
    let settings: AppSettingsProvider
    private let cycle: CycleController
    private let enableBackgroundTick: Bool

    private var tickTask: Task<Void, Never>?
    private var pausedRemaining: TimeInterval?
    private var activeSession: Session?

    init(
        clock: any TimerClock = SystemTimerClock(),
        csvStore: StatsCSVStoreProtocol = StatsCSVStore(),
        slack: SlackClient = LiveSlackClient(),
        sound: SoundPlayerProtocol = SoundPlayer(),
        settings: AppSettingsProvider = UserDefaultsSettings.shared,
        cycle: CycleController = CycleController(),
        enableBackgroundTick: Bool = true
    ) {
        self.clock = clock
        self.csvStore = csvStore
        self.slack = slack
        self.sound = sound
        self.settings = settings
        self.cycle = cycle
        self.enableBackgroundTick = enableBackgroundTick
        refreshTodayStats()
        if enableBackgroundTick {
            startBackgroundTick()
        }
    }

    // MARK: - Public API

    func startRegularFocus(task: String? = nil) {
        let phase = PlannedPhase(
            type: .regularFocus,
            duration: TimeInterval(settings.regularFocusMinutes * 60),
            isDeepFocusBreak: false,
            countsTowardCycle: true
        )
        startPhase(phase, task: task)
    }

    func startDeepFocus(task: String? = nil) {
        let phase = PlannedPhase(
            type: .deepFocus,
            duration: TimeInterval(settings.deepFocusMinutes * 60),
            isDeepFocusBreak: false,
            countsTowardCycle: settings.countDeepFocusTowardCycle
        )
        startPhase(phase, task: task)
    }

    func startShortBreak() {
        let phase = PlannedPhase(
            type: .shortBreak,
            duration: TimeInterval(settings.shortBreakMinutes * 60),
            isDeepFocusBreak: false,
            countsTowardCycle: false
        )
        startPhase(phase, task: nil)
    }

    func startLongBreak() {
        let phase = PlannedPhase(
            type: .longBreak,
            duration: TimeInterval(settings.longBreakMinutes * 60),
            isDeepFocusBreak: false,
            countsTowardCycle: false
        )
        startPhase(phase, task: nil)
    }

    /// Start whatever `nextPlannedPhase` points at (used when auto-flow is off
    /// and the user clicks "Start" on the up-next card).
    func startNextPlannedPhase() {
        guard let phase = nextPlannedPhase else { return }
        startPhase(phase, task: nil)
    }

    func pause() {
        guard isRunning, !isPaused, let end = phaseEndDate else { return }
        pausedRemaining = max(0, end.timeIntervalSince(clock.now()))
        isPaused = true
        remainingSeconds = pausedRemaining ?? 0
    }

    func resume() {
        guard isPaused, let remaining = pausedRemaining else { return }
        let now = clock.now()
        phaseEndDate = now.addingTimeInterval(remaining)
        isPaused = false
        pausedRemaining = nil
        remainingSeconds = remaining
    }

    func skip() {
        guard isRunning, let session = activeSession, let type = currentType else { return }
        var ended = session
        ended.endedAt = clock.now()
        ended.status = .skipped
        log(session: ended)
        finishPhase(completed: type, status: .skipped)
    }

    func resetCycle() {
        cancelPhase()
        cycleState = .initial
        nextPlannedPhase = nil
        currentTask = nil
        // Always try to clean up Slack on reset so a status/DND left behind
        // by a previous session is guaranteed to clear — the `try?` swallows
        // the no-token / transport errors when Slack isn't configured.
        Task { [slack] in
            _ = try? await slack.clearStatus()
            _ = try? await slack.endSnooze()
        }
        dndActive = false
        slackHasError = false
    }

    func shutdown() async {
        cancelPhase()
        tickTask?.cancel()
        tickTask = nil
        if settings.slackEnabled {
            _ = try? await slack.clearStatus()
            if dndActive {
                _ = try? await slack.endSnooze()
            }
        }
        dndActive = false
    }

    /// Called periodically by the background tick task and by tests.
    func tick() {
        guard isRunning, !isPaused, let end = phaseEndDate else { return }
        let now = clock.now()
        let remaining = end.timeIntervalSince(now)
        if remaining <= 0 {
            remainingSeconds = 0
            handlePhaseCompletion()
        } else {
            remainingSeconds = remaining
        }
    }

    // MARK: - Internals

    private func startPhase(_ phase: PlannedPhase, task: String?) {
        cancelPhase()
        let now = clock.now()
        currentType = phase.type
        phaseStartDate = now
        phaseEndDate = now.addingTimeInterval(phase.duration)
        phasePlannedDuration = phase.duration
        remainingSeconds = phase.duration
        isRunning = true
        isPaused = false
        isCurrentPhaseDeepFocusBreak = phase.isDeepFocusBreak
        currentTask = task
        activeSession = Session(
            type: phase.type,
            plannedDuration: phase.duration,
            startedAt: now,
            task: task,
            countsTowardCycle: phase.countsTowardCycle
        )
        nextPlannedPhase = nil
        notifySlackPhaseStart(phase)
    }

    private func handlePhaseCompletion() {
        guard let session = activeSession, let type = currentType else { return }
        var ended = session
        ended.endedAt = clock.now()
        ended.status = .completed
        log(session: ended)
        if settings.playSoundOnPhaseEnd {
            sound.playPhaseEnd()
        }
        finishPhase(completed: type, status: .completed)
    }

    private func finishPhase(completed: SessionType, status: SessionStatus) {
        // Only completed sessions advance the cycle; skipped sessions do not.
        let previousState = cycleState
        if status == .completed {
            cycleState = cycle.updatedState(after: completed, state: previousState, settings: settings)
        }
        let stateForNext = status == .completed ? cycleState : previousState
        let nextPhase = cycle.nextPhase(after: completed, newState: stateForNext, settings: settings)
        nextPlannedPhase = nextPhase
        refreshTodayStats()

        // Clear deep focus DND if transitioning away from deep focus.
        if completed == .deepFocus, dndActive {
            Task { [slack] in
                _ = try? await slack.endSnooze()
            }
            dndActive = false
        }

        // Clear active session.
        activeSession = nil
        currentType = nil
        phaseEndDate = nil
        phaseStartDate = nil
        isRunning = false
        isPaused = false
        isCurrentPhaseDeepFocusBreak = false

        if settings.autoStartNextPhase {
            // Start the next phase immediately. Carry task forward only if same focus? No — drop it.
            startPhase(nextPhase, task: nil)
        } else {
            // Stay idle; clear Slack status between phases if syncing.
            if settings.slackEnabled, settings.slackSyncEveryPhase {
                Task { [slack] in
                    _ = try? await slack.clearStatus()
                }
            }
        }
    }

    private func cancelPhase() {
        activeSession = nil
        currentType = nil
        phaseEndDate = nil
        phaseStartDate = nil
        phasePlannedDuration = 0
        remainingSeconds = 0
        isRunning = false
        isPaused = false
        pausedRemaining = nil
        isCurrentPhaseDeepFocusBreak = false
    }

    private func log(session: Session) {
        do {
            try csvStore.append(session: session)
        } catch {
            // Non-fatal: we don't block the timer on disk errors.
        }
    }

    private func refreshTodayStats() {
        let today = clock.now()
        todayStats = (try? csvStore.dailyStats(for: today)) ?? .empty
    }

    private func notifySlackPhaseStart(_ phase: PlannedPhase) {
        guard settings.slackEnabled, settings.slackSyncEveryPhase else { return }
        let type = phase.type
        let statusEmoji = settings.slackEmoji(for: type)
        let statusText = type.slackStatusText
        let endDate = clock.now().addingTimeInterval(phase.duration)
        let expiration = Int(endDate.timeIntervalSince1970)
        let startDeepDND = (type == .deepFocus)
        let durationMinutes = Int(phase.duration / 60)

        Task { [slack] in
            do {
                try await slack.setStatus(text: statusText, emoji: statusEmoji, expiration: expiration)
                if startDeepDND {
                    try await slack.setSnooze(minutes: durationMinutes)
                }
            } catch {
                await MainActor.run { [weak self] in self?.slackHasError = true }
            }
        }
        if startDeepDND {
            dndActive = true
        }
    }

    private func startBackgroundTick() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run { self?.tick() }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
}
