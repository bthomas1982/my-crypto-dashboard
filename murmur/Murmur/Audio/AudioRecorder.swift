import Foundation
import AVFoundation

/// Captures microphone (and Bluetooth headset) audio, writes it to a file, and
/// streams each buffer to the live transcriber. Configured for background audio
/// so a recording survives the screen locking.
@MainActor
final class AudioRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    /// Rolling input level 0...1 for the waveform UI.
    @Published private(set) var level: Float = 0

    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var startDate: Date?
    private var timer: Timer?

    /// Called with every captured buffer (for live transcription).
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    /// The audio file for the current recording.
    private(set) var currentFileURL: URL?

    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // Persist to an m4a in Documents.
        let filename = "\(UUID().uuidString).m4a"
        let url = URL.documentsDirectory.appendingPathComponent(filename)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
        ]
        file = try AVAudioFile(forWriting: url, settings: settings)
        currentFileURL = url

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? self?.file?.write(from: buffer)
            self?.onBuffer?(buffer)
            self?.updateLevel(buffer)
        }

        engine.prepare()
        try engine.start()

        startDate = .now
        isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startDate else { return }
                self.elapsed = Date.now.timeIntervalSince(start)
            }
        }
    }

    /// Stops capture and returns (fileURL, duration).
    func stop() -> (url: URL?, duration: TimeInterval) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        timer?.invalidate(); timer = nil
        isRecording = false
        let duration = elapsed
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let url = currentFileURL
        return (url, duration)
    }

    private func updateLevel(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames { sum += data[i] * data[i] }
        let rms = frames > 0 ? sqrt(sum / Float(frames)) : 0
        // Normalize to a pleasant 0...1 with a light curve.
        let normalized = min(1, max(0, (rms * 20)))
        Task { @MainActor in self.level = normalized }
    }
}
