import AVFoundation

/// Lightweight AVFoundation wrapper for the app's sound effects. The
/// `.ambient` session category makes playback respect the hardware silent
/// switch automatically, on top of the separate in-app mute toggle in
/// Profile (both read/write the same UserDefaults key, so they stay in
/// sync without any extra plumbing).
@MainActor
final class SoundService {
    static let shared = SoundService()

    static let muteDefaultsKey = "isSoundMuted"

    private var oneShotPlayers: [String: AVAudioPlayer] = [:]
    private var purrPlayer: AVAudioPlayer?

    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.muteDefaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.muteDefaultsKey)
            if newValue { stopPurr() }
        }
    }

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func playTaskCompletion() {
        play("chime")
        play("mew")
    }

    func playLevelUp() {
        play("fanfare")
    }

    func startPurr() {
        guard !isMuted, purrPlayer == nil else { return }
        guard let url = Bundle.main.url(forResource: "purr", withExtension: "wav") else { return }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0.4
        player?.play()
        purrPlayer = player
    }

    func stopPurr() {
        purrPlayer?.stop()
        purrPlayer = nil
    }

    private func play(_ name: String) {
        guard !isMuted else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        if let player {
            oneShotPlayers[name] = player
        }
    }
}
