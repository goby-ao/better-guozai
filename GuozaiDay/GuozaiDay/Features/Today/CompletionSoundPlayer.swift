import AVFAudio
import Foundation

@MainActor
final class CompletionSoundPlayer {
    static let shared = CompletionSoundPlayer()

    enum Sound: String, CaseIterable {
        case taskComplete = "task-complete"
        case dayAchieved = "day-achieved"
    }

    private var players: [Sound: AVAudioPlayer] = [:]
    private weak var activePlayer: AVAudioPlayer?
    private var isSessionConfigured = false

    private init() { }

    func prepare() {
        for sound in Sound.allCases where players[sound] == nil {
            guard let url = soundURL(for: sound), let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = 0.72
            player.prepareToPlay()
            players[sound] = player
        }
    }

    func play(_ sound: Sound) {
        prepare()
        configureSessionIfNeeded()
        guard let player = players[sound] else { return }

        activePlayer?.stop()
        player.currentTime = 0
        player.play()
        activePlayer = player
    }

    private func configureSessionIfNeeded() {
        guard !isSessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isSessionConfigured = true
        } catch {
            // 音效属于辅助反馈；音频会话不可用时不影响打卡本身。
        }
    }

    private func soundURL(for sound: Sound) -> URL? {
        Bundle.main.url(forResource: sound.rawValue, withExtension: "wav", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav")
    }
}
