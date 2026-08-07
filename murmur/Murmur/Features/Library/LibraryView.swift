import SwiftUI
import SwiftData

/// The home screen: your recordings, a prominent record button, and a route to
/// Settings. Mirrors the "scanned, not read" posture — newest capture on top,
/// one obvious action.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    @State private var showRecorder = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if recordings.isEmpty {
                    EmptyLibrary()
                } else {
                    List {
                        ForEach(recordings) { recording in
                            NavigationLink(value: recording) {
                                RecordingRow(recording: recording)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Murmur")
            .navigationDestination(for: Recording.self) { RecordingDetailView(recording: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                RecordButton { showRecorder = true }
            }
            .sheet(isPresented: $showRecorder) {
                RecordView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]
            if let url = recording.audioURL { try? FileManager.default.removeItem(at: url) }
            context.delete(recording)
        }
        try? context.save()
    }
}

private struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.title)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 10) {
                Label(recording.duration.clockString, systemImage: "waveform")
                if !recording.summaries.isEmpty {
                    Label("\(recording.summaries.count)", systemImage: "sparkles")
                        .foregroundStyle(Theme.coral)
                }
                if recording.hasTranscript {
                    Text(recording.transcript.prefix(60))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .font(Theme.mono(12))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyLibrary: View {
    var body: some View {
        ContentUnavailableView {
            Label("Nothing recorded yet", systemImage: "waveform")
        } description: {
            Text("Tap record to capture a meeting, lecture, or voice note. It transcribes on your iPhone — nothing is uploaded.")
        }
    }
}

private struct RecordButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().fill(Theme.coral).frame(width: 14, height: 14)
                Text("Record").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.coral.opacity(0.35)))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
