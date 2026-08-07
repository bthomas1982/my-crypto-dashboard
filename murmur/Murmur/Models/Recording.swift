import Foundation
import SwiftData

/// A single capture: the audio file on disk, its on-device transcript, and any
/// AI summaries the user has generated from it. Everything is local.
@Model
final class Recording {
    var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval

    /// Filename (not full path) of the audio inside the app's Documents dir.
    /// We store the name, not the URL, so the note survives app-container moves.
    var audioFilename: String?

    /// The full transcript produced on-device by SpeechAnalyzer.
    var transcript: String

    /// Locale identifier the transcript was produced in, e.g. "en-US".
    var localeIdentifier: String

    /// Summaries generated from the transcript, newest first.
    @Relationship(deleteRule: .cascade, inverse: \Summary.recording)
    var summaries: [Summary]

    init(
        id: UUID = UUID(),
        title: String = "New recording",
        createdAt: Date = .now,
        duration: TimeInterval = 0,
        audioFilename: String? = nil,
        transcript: String = "",
        localeIdentifier: String = Locale.current.identifier
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.audioFilename = audioFilename
        self.transcript = transcript
        self.localeIdentifier = localeIdentifier
        self.summaries = []
    }

    var hasTranscript: Bool { !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Resolved URL of the audio file, if present.
    var audioURL: URL? {
        guard let name = audioFilename else { return nil }
        return URL.documentsDirectory.appendingPathComponent(name)
    }
}

/// One AI-generated summary. We keep every summary so the user can compare the
/// same transcript through different templates (and different brains).
@Model
final class Summary {
    var id: UUID
    var createdAt: Date
    var templateName: String
    /// Which brain produced it, e.g. "Apple on-device" or "Claude (claude-sonnet-5)".
    var engineName: String
    var content: String
    var recording: Recording?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        templateName: String,
        engineName: String,
        content: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.templateName = templateName
        self.engineName = engineName
        self.content = content
    }
}
