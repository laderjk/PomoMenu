import Foundation
import SwiftUI

enum AppSettingsKey {
    static let regularFocusMinutes = "regularFocusMinutes"
    static let shortBreakMinutes = "shortBreakMinutes"
    static let deepFocusMinutes = "deepFocusMinutes"
    static let deepFocusBreakMinutes = "deepFocusBreakMinutes"
    static let longBreakMinutes = "longBreakMinutes"
    static let pomosPerCycle = "pomosPerCycle"
    static let countDeepFocusTowardCycle = "countDeepFocusTowardCycle"
    static let autoStartNextPhase = "autoStartNextPhase"
    static let playSoundOnPhaseEnd = "playSoundOnPhaseEnd"
    static let slackEnabled = "slackEnabled"
    static let slackSyncEveryPhase = "slackSyncEveryPhase"
    static let slackDNDDeepFocusOnly = "slackDNDDeepFocusOnly"
    static let emojiRegularFocus = "emojiRegularFocus"
    static let emojiDeepFocus = "emojiDeepFocus"
    static let emojiShortBreak = "emojiShortBreak"
    static let emojiLongBreak = "emojiLongBreak"
    static let slackEmojiRegularFocus = "slackEmojiRegularFocus"
    static let slackEmojiDeepFocus = "slackEmojiDeepFocus"
    static let slackEmojiShortBreak = "slackEmojiShortBreak"
    static let slackEmojiLongBreak = "slackEmojiLongBreak"
    static let promptTaskNameOnStart = "promptTaskNameOnStart"
    static let menuBarTimeFormat = "menuBarTimeFormat"
}

enum MenuBarTimeFormat: String, CaseIterable, Identifiable, Sendable {
    case mmss   = "mmss"      // 25:00
    case mLeft  = "m_left"    // 25m left
    case minutes = "min"      // 25 min

    var id: String { rawValue }

    var sampleLabel: String {
        switch self {
        case .mmss:    return "25:00"
        case .mLeft:   return "25m left"
        case .minutes: return "25 min"
        }
    }

    /// Format a time interval for display in the menu bar.
    /// - `mmss` shows MM:SS.
    /// - `mLeft`/`minutes` round UP to the nearest minute so the label doesn't
    ///   immediately drop to 24 after starting a 25-minute session.
    func format(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        switch self {
        case .mmss:
            return String(format: "%02d:%02d", total / 60, total % 60)
        case .mLeft:
            let m = total == 0 ? 0 : (total + 59) / 60
            return "\(m)m left"
        case .minutes:
            let m = total == 0 ? 0 : (total + 59) / 60
            return "\(m) min"
        }
    }
}

protocol AppSettingsProvider: AnyObject, Sendable {
    var regularFocusMinutes: Int { get }
    var shortBreakMinutes: Int { get }
    var deepFocusMinutes: Int { get }
    var deepFocusBreakMinutes: Int { get }
    var longBreakMinutes: Int { get }
    var pomosPerCycle: Int { get }
    var countDeepFocusTowardCycle: Bool { get }
    var autoStartNextPhase: Bool { get }
    var playSoundOnPhaseEnd: Bool { get }

    var slackEnabled: Bool { get }
    var slackSyncEveryPhase: Bool { get }
    var slackDNDDeepFocusOnly: Bool { get }

    func emoji(for type: SessionType) -> String
    func slackEmoji(for type: SessionType) -> String

    var promptTaskNameOnStart: Bool { get }
    var menuBarTimeFormat: MenuBarTimeFormat { get }
}

final class UserDefaultsSettings: AppSettingsProvider, @unchecked Sendable {
    static let shared = UserDefaultsSettings(defaults: .standard)

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            AppSettingsKey.regularFocusMinutes: 25,
            AppSettingsKey.shortBreakMinutes: 5,
            AppSettingsKey.deepFocusMinutes: 50,
            AppSettingsKey.deepFocusBreakMinutes: 15,
            AppSettingsKey.longBreakMinutes: 15,
            AppSettingsKey.pomosPerCycle: 4,
            AppSettingsKey.countDeepFocusTowardCycle: false,
            AppSettingsKey.autoStartNextPhase: true,
            AppSettingsKey.playSoundOnPhaseEnd: true,
            AppSettingsKey.slackEnabled: false,
            AppSettingsKey.slackSyncEveryPhase: true,
            AppSettingsKey.slackDNDDeepFocusOnly: true,
            AppSettingsKey.emojiRegularFocus: "🍅",
            AppSettingsKey.emojiDeepFocus: "🧠",
            AppSettingsKey.emojiShortBreak: "☕️",
            AppSettingsKey.emojiLongBreak: "🌿",
            AppSettingsKey.slackEmojiRegularFocus: ":tomato:",
            AppSettingsKey.slackEmojiDeepFocus: ":brain:",
            AppSettingsKey.slackEmojiShortBreak: ":coffee:",
            AppSettingsKey.slackEmojiLongBreak: ":herb:",
            AppSettingsKey.promptTaskNameOnStart: true,
            AppSettingsKey.menuBarTimeFormat: MenuBarTimeFormat.mmss.rawValue,
        ])
    }

    var regularFocusMinutes: Int { max(1, defaults.integer(forKey: AppSettingsKey.regularFocusMinutes)) }
    var shortBreakMinutes: Int { max(1, defaults.integer(forKey: AppSettingsKey.shortBreakMinutes)) }
    var deepFocusMinutes: Int { max(1, defaults.integer(forKey: AppSettingsKey.deepFocusMinutes)) }
    var deepFocusBreakMinutes: Int { max(1, defaults.integer(forKey: AppSettingsKey.deepFocusBreakMinutes)) }
    var longBreakMinutes: Int { max(1, defaults.integer(forKey: AppSettingsKey.longBreakMinutes)) }
    var pomosPerCycle: Int { max(1, defaults.integer(forKey: AppSettingsKey.pomosPerCycle)) }
    var countDeepFocusTowardCycle: Bool { defaults.bool(forKey: AppSettingsKey.countDeepFocusTowardCycle) }
    var autoStartNextPhase: Bool { defaults.bool(forKey: AppSettingsKey.autoStartNextPhase) }
    var playSoundOnPhaseEnd: Bool { defaults.bool(forKey: AppSettingsKey.playSoundOnPhaseEnd) }
    var slackEnabled: Bool { defaults.bool(forKey: AppSettingsKey.slackEnabled) }
    var slackSyncEveryPhase: Bool { defaults.bool(forKey: AppSettingsKey.slackSyncEveryPhase) }
    var slackDNDDeepFocusOnly: Bool { defaults.bool(forKey: AppSettingsKey.slackDNDDeepFocusOnly) }
    var promptTaskNameOnStart: Bool { defaults.bool(forKey: AppSettingsKey.promptTaskNameOnStart) }
    var menuBarTimeFormat: MenuBarTimeFormat {
        let raw = defaults.string(forKey: AppSettingsKey.menuBarTimeFormat) ?? ""
        return MenuBarTimeFormat(rawValue: raw) ?? .mmss
    }

    func emoji(for type: SessionType) -> String {
        let key: String = {
            switch type {
            case .regularFocus: return AppSettingsKey.emojiRegularFocus
            case .deepFocus:    return AppSettingsKey.emojiDeepFocus
            case .shortBreak:   return AppSettingsKey.emojiShortBreak
            case .longBreak:    return AppSettingsKey.emojiLongBreak
            }
        }()
        return defaults.string(forKey: key) ?? type.defaultEmoji
    }

    func slackEmoji(for type: SessionType) -> String {
        let key: String = {
            switch type {
            case .regularFocus: return AppSettingsKey.slackEmojiRegularFocus
            case .deepFocus:    return AppSettingsKey.slackEmojiDeepFocus
            case .shortBreak:   return AppSettingsKey.slackEmojiShortBreak
            case .longBreak:    return AppSettingsKey.slackEmojiLongBreak
            }
        }()
        return defaults.string(forKey: key) ?? type.slackEmojiDefault
    }

    func duration(for type: SessionType) -> TimeInterval {
        let minutes: Int
        switch type {
        case .regularFocus: minutes = regularFocusMinutes
        case .deepFocus:    minutes = deepFocusMinutes
        case .shortBreak:   minutes = shortBreakMinutes
        case .longBreak:    minutes = longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }
}
