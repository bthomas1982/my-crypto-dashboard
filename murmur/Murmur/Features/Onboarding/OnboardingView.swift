import SwiftUI

/// First-run flow. Sells the two things that matter — it's private, and it works
/// with whatever AI you want — then gets out of the way. No account, no sign-up.
struct OnboardingView: View {
    let onDone: () -> Void
    @Environment(AIRouter.self) private var router
    @State private var page = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {
                Panel(
                    symbol: "waveform",
                    title: "Record anything",
                    message: "Meetings, lectures, calls on speaker, or a quick voice note. One tap and Murmur is listening."
                ).tag(0)

                Panel(
                    symbol: "lock.shield",
                    title: "Transcribed on your iPhone",
                    message: "Your audio never leaves the device. Transcription runs on-device — unlimited, private, and free."
                ).tag(1)

                Panel(
                    symbol: "sparkles",
                    title: "Think with your own AI",
                    message: "Summaries and answers come from Apple's free on-device model — or plug in your own Claude or OpenAI key for more."
                ).tag(2)

                brainChoice.tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < 3 ? "Continue" : "Start using Murmur") {
                if page < 3 { withAnimation { page += 1 } } else { onDone() }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.coral, in: Capsule())
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    private var brainChoice: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "cpu").font(.system(size: 54)).foregroundStyle(Theme.coral)
            Text("Pick your brain").font(.title.bold())
            Text("You can change this anytime in Settings.")
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                ForEach(AIRouter.Provider.allCases) { provider in
                    Button {
                        router.provider = provider
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.label).font(.headline)
                                Text(provider.blurb).font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: router.provider == provider ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(router.provider == provider ? Theme.coral : .secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .tint(.primary)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

private struct Panel: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 64))
                .foregroundStyle(Theme.coral)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer(); Spacer()
        }
    }
}
