import Foundation
import AppKit

protocol SoundPlayerProtocol: Sendable {
    func playPhaseEnd()
}

struct SoundPlayer: SoundPlayerProtocol {
    let soundName: String

    init(soundName: String = "Glass") {
        self.soundName = soundName
    }

    func playPhaseEnd() {
        guard let sound = NSSound(named: soundName) else { return }
        sound.play()
    }
}

struct NoopSoundPlayer: SoundPlayerProtocol {
    func playPhaseEnd() {}
}
