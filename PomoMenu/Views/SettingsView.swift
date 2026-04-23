import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var engine: TimerEngine

    @AppStorage(AppSettingsKey.regularFocusMinutes) private var regularFocusMinutes: Int = 25
    @AppStorage(AppSettingsKey.shortBreakMinutes) private var shortBreakMinutes: Int = 5
    @AppStorage(AppSettingsKey.deepFocusMinutes) private var deepFocusMinutes: Int = 50
    @AppStorage(AppSettingsKey.deepFocusBreakMinutes) private var deepFocusBreakMinutes: Int = 15
    @AppStorage(AppSettingsKey.longBreakMinutes) private var longBreakMinutes: Int = 15
    @AppStorage(AppSettingsKey.pomosPerCycle) private var pomosPerCycle: Int = 4
    @AppStorage(AppSettingsKey.countDeepFocusTowardCycle) private var countDeepFocusTowardCycle: Bool = false
    @AppStorage(AppSettingsKey.autoStartNextPhase) private var autoStartNextPhase: Bool = true
    @AppStorage(AppSettingsKey.playSoundOnPhaseEnd) private var playSoundOnPhaseEnd: Bool = true
    @AppStorage(AppSettingsKey.menuBarTimeFormat) private var menuBarTimeFormatRaw: String = MenuBarTimeFormat.mmss.rawValue

    @AppStorage(AppSettingsKey.slackEnabled) private var slackEnabled: Bool = false
    @AppStorage(AppSettingsKey.slackSyncEveryPhase) private var slackSyncEveryPhase: Bool = true
    @AppStorage(AppSettingsKey.slackDNDDeepFocusOnly) private var slackDNDDeepFocusOnly: Bool = true

    @AppStorage(AppSettingsKey.emojiRegularFocus) private var emojiRegularFocus: String = "🍅"
    @AppStorage(AppSettingsKey.emojiDeepFocus) private var emojiDeepFocus: String = "🧠"
    @AppStorage(AppSettingsKey.emojiShortBreak) private var emojiShortBreak: String = "☕️"
    @AppStorage(AppSettingsKey.emojiLongBreak) private var emojiLongBreak: String = "🌿"

    @AppStorage(AppSettingsKey.slackEmojiRegularFocus) private var slackEmojiRegularFocus: String = ":tomato:"
    @AppStorage(AppSettingsKey.slackEmojiDeepFocus) private var slackEmojiDeepFocus: String = ":brain:"
    @AppStorage(AppSettingsKey.slackEmojiShortBreak) private var slackEmojiShortBreak: String = ":coffee:"
    @AppStorage(AppSettingsKey.slackEmojiLongBreak) private var slackEmojiLongBreak: String = ":herb:"

    @State private var slackToken: String = KeychainStore.shared.slackToken() ?? ""
    @State private var connectionStatus: String?
    @State private var connectionError: String?
    @State private var testing: Bool = false

    var body: some View {
        TabView {
            timingTab
                .tabItem { Label("Timing", systemImage: "timer") }
            behaviorTab
                .tabItem { Label("Behavior", systemImage: "gear") }
            slackTab
                .tabItem { Label("Slack", systemImage: "bubble.left.and.bubble.right") }
            statsTab
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .frame(width: 480, height: 420)
        .padding(16)
    }

    // MARK: - Tabs

    @ViewBuilder
    private var timingTab: some View {
        Form {
            Section("Durations (minutes)") {
                Stepper("Regular focus: \(regularFocusMinutes)", value: $regularFocusMinutes, in: 1...180)
                Stepper("Short break: \(shortBreakMinutes)", value: $shortBreakMinutes, in: 1...60)
                Stepper("Deep focus: \(deepFocusMinutes)", value: $deepFocusMinutes, in: 5...240)
                Stepper("Deep focus break: \(deepFocusBreakMinutes)", value: $deepFocusBreakMinutes, in: 1...120)
                Stepper("Long break: \(longBreakMinutes)", value: $longBreakMinutes, in: 1...120)
            }
            Section("Cycle") {
                Stepper("Pomos per cycle: \(pomosPerCycle)", value: $pomosPerCycle, in: 1...12)
                Toggle("Count deep focus toward cycle", isOn: $countDeepFocusTowardCycle)
            }
        }
    }

    @ViewBuilder
    private var behaviorTab: some View {
        Form {
            Section("Flow") {
                Toggle("Auto-start next phase", isOn: $autoStartNextPhase)
                Toggle("Play sound on phase end", isOn: $playSoundOnPhaseEnd)
            }
            Section("Menu bar display") {
                Picker("Time format", selection: $menuBarTimeFormatRaw) {
                    ForEach(MenuBarTimeFormat.allCases) { fmt in
                        Text(fmt.sampleLabel).tag(fmt.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            Section("Emoji (menu bar)") {
                LabeledContent("Regular focus") {
                    TextField("", text: $emojiRegularFocus).frame(width: 80)
                }
                LabeledContent("Deep focus") {
                    TextField("", text: $emojiDeepFocus).frame(width: 80)
                }
                LabeledContent("Short break") {
                    TextField("", text: $emojiShortBreak).frame(width: 80)
                }
                LabeledContent("Long break") {
                    TextField("", text: $emojiLongBreak).frame(width: 80)
                }
            }
        }
    }

    @ViewBuilder
    private var slackTab: some View {
        Form {
            Section("Connection") {
                Toggle("Sync with Slack", isOn: $slackEnabled)
                SecureField("User token (xoxp-…)", text: $slackToken)
                    .onSubmit { KeychainStore.shared.setSlackToken(slackToken) }
                HStack {
                    Button("Save token") {
                        KeychainStore.shared.setSlackToken(slackToken)
                        connectionStatus = "Saved"
                        connectionError = nil
                    }
                    Button("Test connection") {
                        KeychainStore.shared.setSlackToken(slackToken)
                        testConnection()
                    }
                    .disabled(testing || slackToken.isEmpty)
                    Spacer()
                    if let status = connectionStatus {
                        Text(status).foregroundStyle(.secondary)
                    }
                    if let err = connectionError {
                        Text(err).foregroundStyle(.red)
                    }
                }
            }
            Section("Behavior") {
                Toggle("Sync status on every phase", isOn: $slackSyncEveryPhase)
                Toggle("Enable DND for deep focus only", isOn: $slackDNDDeepFocusOnly)
            }
            Section("Status emoji (Slack)") {
                LabeledContent("Regular focus") {
                    TextField("", text: $slackEmojiRegularFocus).frame(width: 120)
                }
                LabeledContent("Deep focus") {
                    TextField("", text: $slackEmojiDeepFocus).frame(width: 120)
                }
                LabeledContent("Short break") {
                    TextField("", text: $slackEmojiShortBreak).frame(width: 120)
                }
                LabeledContent("Long break") {
                    TextField("", text: $slackEmojiLongBreak).frame(width: 120)
                }
            }
        }
    }

    @ViewBuilder
    private var statsTab: some View {
        Form {
            Section("Today") {
                LabeledContent("Pomodoros completed", value: "\(engine.todayStats.pomosCompleted)")
                LabeledContent("Deep focus completed", value: "\(engine.todayStats.deepFocusCompleted)")
                LabeledContent("Focused minutes", value: "\(engine.todayStats.totalFocusedMinutes)")
            }
            Section("CSV") {
                let url = StatsCSVStore().fileURL
                LabeledContent("Location", value: url.path)
                    .textSelection(.enabled)
                Button("Reveal stats in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        }
    }

    private func testConnection() {
        testing = true
        connectionStatus = "Testing…"
        connectionError = nil
        let client = LiveSlackClient()
        Task {
            do {
                let user = try await client.testConnection()
                await MainActor.run {
                    connectionStatus = user.isEmpty ? "OK" : "OK — \(user)"
                    connectionError = nil
                    testing = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = nil
                    connectionError = "Failed: \(error)"
                    testing = false
                }
            }
        }
    }
}
