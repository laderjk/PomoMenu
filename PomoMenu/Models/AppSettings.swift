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
