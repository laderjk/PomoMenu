import SwiftUI
import AppKit

struct MenuBarContent: View {
    @ObservedObject var engine: TimerEngine
    @Environment(\.openSettings) private var openSettings

    @State private var selectedType: SessionType = .regularFocus
    @State private var taskInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            progressSection
            if showNextUpCard {
                nextUpCard
            }
            Divider()
            startRow
            taskField
            transportRow
            Divider()
            statsSection
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var showNextUpCard: Bool {
        engine.nextPlannedPhase != nil && !engine.isRunning
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.headline)
            Spacer()
            if engine.slackHasError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Slack sync failed — check settings")
            }
        }
    }

    private var headerTitle: String {
        if let type = engine.currentType {
            let label = engine.isCurrentPhaseDeepFocusBreak ? "Deep Focus Break" : type.displayName
            return "\(engine.settings.emoji(for: type))  \(label)"
        }
        if let next = engine.nextPlannedPhase {
            return "Up next: \(next.type.displayName)"
        }
        return "Pomo"
    }

    @ViewBuilder
    private var progressSection: some View {
        ZStack {
            ProgressRing(progress: progress, tint: ringTint, lineWidth: 10)
                .frame(width: 120, height: 120)
            VStack(spacing: 2) {
                Text(formatMMSS(engine.remainingSeconds))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let task = engine.currentTask, !task.isEmpty {
                    Text(task)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var progress: Double {
        let total = engine.phasePlannedDuration
        guard total > 0 else { return 0 }
        let elapsed = total - engine.remainingSeconds
        return elapsed / total
    }

    private var ringTint: Color {
        guard let type = engine.currentType else { return .secondary }
        switch type {
        case .regularFocus: return .red
        case .deepFocus:    return .purple
        case .shortBreak:   return .teal
        case .longBreak:    return .green
        }
    }

    // Up-next card — appears when auto-flow is off and the engine has a
    // planned next phase waiting for user confirmation.
    @ViewBuilder
    private var nextUpCard: some View {
        if let next = engine.nextPlannedPhase {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Up next")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(engine.settings.emoji(for: next.type)) \(nextPhaseLabel(next))")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    engine.startNextPlannedPhase()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(minWidth: 60)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
        }
    }

    private func nextPhaseLabel(_ phase: PlannedPhase) -> String {
        let name = phase.isDeepFocusBreak ? "Deep Focus Break" : phase.type.displayName
        let minutes = Int((phase.duration / 60).rounded())
        return "\(name) · \(minutes) min"
    }

    // Session-type toggle (Focus / Deep / Short / Long) + Start button.
    @ViewBuilder
    private var startRow: some View {
        HStack(spacing: 8) {
            Picker("", selection: $selectedType) {
                Text("Focus").tag(SessionType.regularFocus)
                Text("Deep").tag(SessionType.deepFocus)
                Text("Short").tag(SessionType.shortBreak)
                Text("Long").tag(SessionType.longBreak)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(engine.isRunning)

            Button {
                startSelected()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .frame(minWidth: 60)
            }
            .keyboardShortcut(showNextUpCard ? .init("s", modifiers: .command) : .defaultAction)
            .disabled(engine.isRunning)
        }
    }

    // Inline task field — only meaningful for focus sessions.
    @ViewBuilder
    private var taskField: some View {
        TextField(taskFieldPlaceholder, text: $taskInput)
            .textFieldStyle(.roundedBorder)
            .onSubmit { if !engine.isRunning { startSelected() } }
            .disabled(engine.isRunning || !selectedType.isFocus)
    }

    private var taskFieldPlaceholder: String {
        selectedType.isFocus ? "Task (optional)" : "Task (breaks have no task)"
    }

    // Pause / Skip / Reset — visible once a session is running.
    @ViewBuilder
    private var transportRow: some View {
        HStack(spacing: 8) {
            if engine.isRunning && !engine.isPaused {
                Button { engine.pause() } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
            } else if engine.isPaused {
                Button { engine.resume() } label: {
                    Label("Resume", systemImage: "play.fill")
                }
            } else {
                Button {} label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .disabled(true)
            }
            Button {
                engine.skip()
            } label: {
                Label("Skip", systemImage: "forward.fill")
            }
            .disabled(!engine.isRunning)
            Button {
                engine.resetCycle()
                taskInput = ""
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        HStack(alignment: .top) {
            statCell(title: "Pomos", value: "\(engine.todayStats.pomosCompleted)")
            Spacer()
            statCell(title: "Deep", value: "\(engine.todayStats.deepFocusCompleted)")
            Spacer()
            statCell(title: "Focus min", value: "\(engine.todayStats.totalFocusedMinutes)")
        }
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            Button("Open Settings…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            Button("Quit") {
                Task {
                    await engine.shutdown()
                    NSApp.terminate(nil)
                }
            }
        }
    }

    // MARK: - Actions

    private func startSelected() {
        let task = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskOrNil: String? = task.isEmpty ? nil : task
        switch selectedType {
        case .regularFocus: engine.startRegularFocus(task: taskOrNil)
        case .deepFocus:    engine.startDeepFocus(task: taskOrNil)
        case .shortBreak:   engine.startShortBreak()
        case .longBreak:    engine.startLongBreak()
        }
        // Breaks don't carry a task; clear the field so the user doesn't
        // think a typed label is being associated with the break.
        if !selectedType.isFocus { taskInput = "" }
    }

    private func formatMMSS(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
