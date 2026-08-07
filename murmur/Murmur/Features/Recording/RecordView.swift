import SwiftUI
import SwiftData

/// The live recording screen: a pulsing record indicator, a running clock, a
/// simple level meter, and the transcript appearing in real time so the user
/// can see it's working.
struct RecordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var session = RecordingSession()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                LevelMeter(level: session.level)
                    .frame(height: 64)
                    .padding(.horizontal)
                transcriptView
                Spacer(minLength: 0)
                controls
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        session.cancel(); dismiss()
                    }
                }
            }
            .task {
                if session.state == .idle { await session.begin() }
            }
            .interactiveDismissDisabled(session.state == .recording)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            switch session.state {
            case .recording:
                HStack(spacing: 10) {
                    PulsingDot()
                    Text(session.elapsed.clockString)
                        .font(Theme.mono(34, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            case .requestingPermission:
                Text("Starting…").font(.title2)
            case .saving:
                ProgressView("Saving & finishing transcript…")
            case .denied:
                PermissionDenied()
            case .idle:
                Text("Ready").font(.title2).foregroundStyle(.secondary)
            }
        }
    }

    private var transcriptView: some View {
        ScrollView {
            Text(session.liveTranscript.isEmpty
                 ? "Transcript will appear here as you speak…"
                 : session.liveTranscript)
                .font(.body)
                .foregroundStyle(session.liveTranscript.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(maxHeight: 280)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var controls: some View {
        if session.state == .recording {
            Button {
                Task {
                    let recording = await session.finishAndSave(into: context)
                    dismiss()
                    _ = recording
                }
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 16, height: 16)
                    Text("Stop & Save").font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.coral, in: Capsule())
                .foregroundStyle(.white)
            }
        }
    }
}

private struct PulsingDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Theme.coral)
            .frame(width: 16, height: 16)
            .scaleEffect(on ? 1 : 0.7)
            .opacity(on ? 1 : 0.6)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// A lightweight animated level meter driven by the recorder's RMS.
private struct LevelMeter: View {
    let level: Float
    private let bars = 32

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<bars, id: \.self) { i in
                    Capsule()
                        .fill(color(for: i))
                        .frame(height: height(for: i, in: geo.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func height(for i: Int, in maxH: CGFloat) -> CGFloat {
        // Center-weighted so it looks like a live waveform.
        let center = Double(bars) / 2
        let distance = abs(Double(i) - center) / center
        let envelope = 1 - distance * 0.7
        let jitter = Double((i * 37) % 13) / 13.0 * 0.5 + 0.5
        let h = Double(level) * envelope * jitter
        return max(4, CGFloat(h) * maxH)
    }

    private func color(for i: Int) -> Color {
        Theme.coral.opacity(0.5 + Double((i % 5)) / 10)
    }
}

private struct PermissionDenied: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash").font(.largeTitle).foregroundStyle(Theme.warn)
            Text("Microphone or Speech access is off")
                .font(.headline)
            Text("Enable them in Settings ▸ Murmur to record and transcribe.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
