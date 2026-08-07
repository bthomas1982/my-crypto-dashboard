import Foundation
import SwiftUI
import SwiftData

/// Coordinates the recorder and the live transcriber for one capture, then
/// persists the result as a Recording. Keeps all the async wiring out of the view.
@MainActor
@Observable
final class RecordingSession {
    enum State: Equatable { case idle, requestingPermission, recording, saving, denied }

    var state: State = .idle
    var elapsed: TimeInterval = 0
    var level: Float = 0
    var liveTranscript: String = ""

    private let recorder = AudioRecorder()
    private let transcriber = LiveTranscriber()
    private var tickTask: Task<Void, Never>?

    func begin() async {
        state = .requestingPermission
        let mic = await AudioRecorder.requestMicrophonePermission()
        let speech = await LiveTranscriber.requestAuthorization()
        guard mic && speech else { state = .denied; return }

        do {
            try await transcriber.start()
            recorder.onBuffer = { [weak self] buffer in
                self?.transcriber.feed(buffer)
            }
            try recorder.start()
            state = .recording
            observe()
        } catch {
            state = .idle
        }
    }

    private func observe() {
        tickTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.state == .recording {
                self.elapsed = self.recorder.elapsed
                self.level = self.recorder.level
                self.liveTranscript = self.transcriber.fullText
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    /// Stop, transcribe the tail, and save. Returns the persisted Recording.
    @discardableResult
    func finishAndSave(into context: ModelContext) async -> Recording? {
        guard state == .recording else { return nil }
        state = .saving
        tickTask?.cancel()

        let (url, duration) = recorder.stop()
        let transcript = await transcriber.finish()

        let recording = Recording(
            title: Self.defaultTitle(),
            duration: duration,
            audioFilename: url?.lastPathComponent,
            transcript: transcript
        )
        context.insert(recording)
        try? context.save()
        state = .idle
        return recording
    }

    func cancel() {
        tickTask?.cancel()
        _ = recorder.stop()
        Task { _ = await transcriber.finish() }
        state = .idle
    }

    private static func defaultTitle() -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE d MMM, h:mm a"
        return df.string(from: .now)
    }
}
