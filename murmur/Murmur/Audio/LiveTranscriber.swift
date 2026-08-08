import Foundation
import Speech
@preconcurrency import AVFoundation

/// On-device transcription via iOS 26's SpeechAnalyzer / SpeechTranscriber.
/// No length cap, no network, no per-minute cost — the whole reason Murmur can
/// undercut Plaud. We feed PCM buffers in as we record and read text out.
///
/// NOTE: SpeechAnalyzer is new in iOS 26. The exact initializer labels and the
/// result type shape below reflect the WWDC'25 API; verify against the shipping
/// SDK in Xcode (autocomplete will confirm) — this is the one place signatures
/// may need a small nudge.
@MainActor
final class LiveTranscriber: ObservableObject {
    /// Text confirmed by the recognizer (won't change).
    @Published private(set) var finalizedText: String = ""
    /// The current in-progress hypothesis (updates rapidly, may change).
    @Published private(set) var volatileText: String = ""

    var fullText: String {
        volatileText.isEmpty ? finalizedText : finalizedText + volatileText
    }

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    /// The audio format the analyzer wants us to feed it, if it differs from the
    /// mic's native format we convert before yielding.
    private(set) var analyzerFormat: AVAudioFormat?

    /// Request speech permission up front.
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    func start(locale: Locale = .current) async throws {
        finalizedText = ""
        volatileText = ""

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        self.transcriber = transcriber

        // Make sure the language model assets are installed on this device.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = continuation
        try await analyzer.start(inputSequence: stream)

        // Drain results as they arrive.
        resultsTask = Task { [weak self] in
            guard let transcriber = self?.transcriber else { return }
            do {
                for try await result in transcriber.results {
                    let piece = String(result.text.characters)
                    await MainActor.run {
                        if result.isFinal {
                            self?.finalizedText += piece
                            self?.volatileText = ""
                        } else {
                            self?.volatileText = piece
                        }
                    }
                }
            } catch {
                // Recognition ended; leave whatever we have.
            }
        }
    }

    /// Feed one buffer of captured audio. Converts to the analyzer's format if needed.
    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let continuation = inputContinuation else { return }
        if let target = analyzerFormat,
           buffer.format != target,
           let converted = Self.convert(buffer, to: target) {
            continuation.yield(AnalyzerInput(buffer: converted))
        } else {
            continuation.yield(AnalyzerInput(buffer: buffer))
        }
    }

    /// Flush remaining audio and return the final transcript.
    func finish() async -> String {
        inputContinuation?.finish()
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        let text = finalizedText.isEmpty ? volatileText : finalizedText
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Format conversion

    private static func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }
}
