import SwiftUI

/// Compact transport for listening back while reading the transcript.
struct PlaybackBar: View {
    @Bindable var player: AudioPlayer
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                Button { player.skip(-15) } label: {
                    Image(systemName: "gobackward.15").font(.title3)
                }
                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Theme.coral)
                }
                Button { player.skip(15) } label: {
                    Image(systemName: "goforward.15").font(.title3)
                }
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(
                    get: { scrubbing ? scrubValue : player.currentTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(player.duration, 0.1),
                onEditingChanged: { editing in
                    scrubbing = editing
                    if !editing { player.seek(to: scrubValue) }
                }
            )
            .tint(Theme.coral)

            HStack {
                Text(player.currentTime.clockString)
                Spacer()
                Text(player.duration.clockString)
            }
            .font(Theme.mono(11))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
