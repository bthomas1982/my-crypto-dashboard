import SwiftUI
import SwiftData
import AVFoundation

/// One recording: play it back, read/edit the transcript, and run any template
/// through the selected brain to produce summaries. This is where capture
/// becomes intelligence.
struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @Environment(AIRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \SummaryTemplate.sortIndex) private var templates: [SummaryTemplate]

    @State private var showTemplatePicker = false
    @State private var runningTemplate: SummaryTemplate?
    @State private var errorMessage: String?
    @State private var editingTranscript = false

    var body: some View {
        List {
            summariesSection
            transcriptSection
        }
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTemplatePicker = true
                } label: {
                    Label("Summarize", systemImage: "sparkles")
                }
                .disabled(!recording.hasTranscript || runningTemplate != nil)
            }
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(templates: templates) { template in
                showTemplatePicker = false
                Task { await run(template) }
            }
        }
        .alert("Couldn't summarize", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Summaries

    @ViewBuilder private var summariesSection: some View {
        Section {
            if let running = runningTemplate {
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading) {
                        Text("Summarizing with \(router.provider.label)…").font(.subheadline)
                        Text(running.name).font(Theme.mono(12)).foregroundStyle(.secondary)
                    }
                }
            }
            if recording.summaries.isEmpty && runningTemplate == nil {
                Text("Tap **Summarize** to turn this transcript into notes with your chosen AI.")
                    .foregroundStyle(.secondary)
            }
            ForEach(recording.summaries.sorted { $0.createdAt > $1.createdAt }) { summary in
                SummaryCard(summary: summary) { delete(summary) }
            }
        } header: {
            Text("Summaries")
        }
    }

    // MARK: Transcript

    @ViewBuilder private var transcriptSection: some View {
        Section {
            if editingTranscript {
                TextEditor(text: $recording.transcript)
                    .frame(minHeight: 200)
                    .font(.body)
            } else {
                Text(recording.hasTranscript ? recording.transcript : "No transcript.")
                    .font(.body)
                    .foregroundStyle(recording.hasTranscript ? .primary : .secondary)
                    .textSelection(.enabled)
            }
        } header: {
            HStack {
                Text("Transcript")
                Spacer()
                Button(editingTranscript ? "Done" : "Edit") {
                    editingTranscript.toggle()
                    if !editingTranscript { try? context.save() }
                }
                .font(.caption)
            }
        } footer: {
            Text("Transcribed on-device. Fix names or terms here before summarizing.")
        }
    }

    // MARK: Actions

    private func run(_ template: SummaryTemplate) async {
        runningTemplate = template
        defer { runningTemplate = nil }
        do {
            let result = try await router.summarize(
                transcript: recording.transcript,
                instructions: template.instructions
            )
            let summary = Summary(
                templateName: template.name,
                engineName: result.attribution,
                content: result.text
            )
            summary.recording = recording
            recording.summaries.append(summary)
            context.insert(summary)
            try? context.save()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func delete(_ summary: Summary) {
        recording.summaries.removeAll { $0.id == summary.id }
        context.delete(summary)
        try? context.save()
    }
}

private struct SummaryCard: View {
    let summary: Summary
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(summary.templateName, systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Menu {
                    Button {
                        UIPasteboard.general.string = summary.content
                    } label: { Label("Copy", systemImage: "doc.on.doc") }
                    ShareLink(item: summary.content) { Label("Share", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                }
            }
            Text(summary.content)
                .font(.body)
                .textSelection(.enabled)
            Text(summary.engineName)
                .font(Theme.mono(11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct TemplatePickerSheet: View {
    let templates: [SummaryTemplate]
    let onPick: (SummaryTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(templates) { template in
                Button { onPick(template) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: template.symbol)
                            .foregroundStyle(Theme.coral)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name).font(.headline)
                            Text(template.instructions.prefix(70))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .tint(.primary)
            }
            .navigationTitle("Choose a template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
