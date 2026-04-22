import Foundation

enum SessionType: String, CaseIterable, Codable, Identifiable, Sendable {
    case regularFocus
    case deepFocus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var defaultEmoji: String {
        switch self {
        case .regularFocus: return "🍅"
        case .deepFocus:    return "🧠"
        case .shortBreak:   return "☕️"
        case .longBreak:    return "🌿"
        }
    }

    var displayName: String {
        switch self {
        case .regularFocus: return "Focus"
        case .deepFocus:    return "Deep Focus"
        case .shortBreak:   return "Short Break"
        case .longBreak:    return "Long Break"
        }
    }

    var csvKey: String {
        switch self {
        case .regularFocus: return "regular"
        case .deepFocus:    return "deep"
        case .shortBreak:   return "short_break"
        case .longBreak:    return "long_break"
        }
    }

    var isFocus: Bool {
        self == .regularFocus || self == .deepFocus
    }

    var isBreak: Bool { !isFocus }

    var slackStatusText: String {
        switch self {
        case .regularFocus: return "Focusing"
        case .deepFocus:    return "Deep focus — do not disturb"
        case .shortBreak:   return "On a break"
        case .longBreak:    return "On a long break"
        }
    }

    var slackEmojiDefault: String {
        switch self {
        case .regularFocus: return ":tomato:"
        case .deepFocus:    return ":brain:"
        case .shortBreak:   return ":coffee:"
        case .longBreak:    return ":herb:"
        }
    }
}
