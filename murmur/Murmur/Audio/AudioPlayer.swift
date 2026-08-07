import Foundation
import AVFoundation

/// Plays back a recording with a scrubbable position. Used by the detail screen
/// so you can listen while reading the transcript.
@MainActor
@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var ticker: Timer?

    func load(url: URL) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            self.duration = player.duration
            self.currentTime = 0
        } catch {
            self.player = nil
        }
    }

    func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            ticker?.invalidate()
        } else {
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            startTicker()
        }
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, time), player.duration)
        currentTime = player.currentTime
    }

    func skip(_ delta: TimeInterval) { seek(to: currentTime + delta) }

    func stop() {
        player?.stop()
        ticker?.invalidate(); ticker = nil
        isPlaying = false
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.ticker?.invalidate()
        }
    }
}
