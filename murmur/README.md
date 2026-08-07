# Murmur

**Capture on your phone. Think with your own AI.**

Murmur is an iOS notetaker that records meetings, lectures, and voice notes,
transcribes them **entirely on-device**, and turns them into structured notes
using **whatever AI the buyer plugs in** — Apple's free on-device model out of
the box, or their own Claude / OpenAI / compatible key for higher quality.

It's built to be **sold once** — no subscription, no backend, no per-minute
metering. That's the whole point: the expensive parts of a Plaud-style product
(transcription minutes, cloud AI) are things the iPhone now does for free or the
buyer already pays for.

---

## Why this exists

Plaud sells a $159–$179 recorder and then charges a monthly subscription to
transcribe and summarize (300 free minutes, then $18–$20/mo). Two facts collapse
that model:

1. **iOS 26 transcribes for free, on-device, unlimited** via the new
   `SpeechAnalyzer` framework — no minute meter, no cloud.
2. **iOS 26 ships a free on-device LLM** (`FoundationModels`) — good summaries
   with zero setup, zero key, zero cost — and any cloud model plugs into the
   same code path.

So Murmur is: **local transcription → pluggable AI brain → your notes.** Audio
never has to leave the phone; only the transcript text you choose to summarize is
sent, straight from the device to the AI provider you selected, using your key.

---

## Architecture

```
 ┌─────────────── on your iPhone ───────────────┐   ┌──── your AI ────┐
 │  AudioRecorder ── buffers ──► LiveTranscriber │   │  Apple on-device│
 │  (AVAudioEngine)             (SpeechAnalyzer) │   │  Claude (key)   │
 │        │                          │           │   │  OpenAI (key)   │
 │     .m4a file                 transcript      │   └────────▲────────┘
 │        └──────────► Recording (SwiftData) ◄──────── transcript text
 │                          │                    │            │
 │                    RecordingDetailView ───────┼────────────┘
 │                    (pick template, summarize) │   returns a Summary
 └───────────────────────────────────────────────┘
```

The one abstraction that makes it AI-agnostic is `SummarizationEngine`
(`AI/SummarizationEngine.swift`). Every provider is one conformer:

| File | Brain | Key needed | Notes |
|------|-------|-----------|-------|
| `AppleFoundationEngine.swift` | Apple on-device (`FoundationModels`) | No | Default. Free, private, offline. ~3B model. |
| `ClaudeEngine.swift` | Anthropic Claude | Yes | Buyer's own API key. Best for long/complex transcripts. |
| `OpenAIEngine.swift` | OpenAI / compatible | Yes | Also OpenRouter, Azure, local servers via `baseURL`. |

`AIRouter` holds the user's choice and hands the rest of the app the right
engine. Adding a provider = adding one file.

### Project layout

```
murmur/
├── project.yml                 # XcodeGen — generates the .xcodeproj
├── Murmur.storekit             # StoreKit config for testing packs in Xcode
├── docs/LISTING.md             # App Store listing copy
└── Murmur/
    ├── App/                    # entry point, SharedStore, Info.plist, entitlements
    ├── Models/                 # SwiftData: Recording, Summary, SummaryTemplate
    ├── Audio/                  # AudioRecorder, LiveTranscriber (STT), AudioPlayer
    ├── AI/                     # SummarizationEngine + providers + router + Keychain
    ├── Store/                  # StoreManager (StoreKit 2), VerticalPacks
    ├── Intents/                # App Intents / Siri Shortcuts
    ├── Features/               # SwiftUI screens
    │   ├── Onboarding/         # first-run flow
    │   ├── Library/            # home list
    │   ├── Recording/          # record, detail, playback
    │   ├── Ask/                # "ask your notes" chat
    │   ├── Store/              # template-pack store
    │   └── Settings/           # provider/key, templates, packs
    ├── Resources/              # Assets.xcassets (app icon, accent color)
    └── Support/                # Theme, built-in templates, NoteExporter
```

---

## Build it (on a Mac)

Murmur is a native iOS app, so it needs **Xcode on macOS** to compile — it can't
be built from a phone or a Linux box. The source has no third-party Swift
dependencies.

```bash
brew install xcodegen           # one-time
cd murmur
xcodegen generate               # creates Murmur.xcodeproj from project.yml
open Murmur.xcodeproj
```

Then in Xcode:

1. Set your **Development Team** (Signing & Capabilities) — a free personal
   Apple ID works for running on your own device.
2. Select your iPhone (must be running **iOS 26+**) and Run.
3. On first launch, grant **Microphone** and **Speech Recognition**. In
   **Settings ▸ Apple Intelligence**, make sure it's on so the free on-device
   summarizer works — or add your own Claude/OpenAI key in Murmur's Settings.

---

## Honest status — read before building

This is a **Phase-1 MVP scaffold**: the architecture, data model, UI, and the
pluggable-AI layer are complete and coherent, but a few things need a pass in
Xcode:

- **`SpeechAnalyzer` / `SpeechTranscriber` (in `LiveTranscriber.swift`) are new
  in iOS 26.** The code follows the WWDC'25 API shape, but exact initializer
  labels and the `result` type may need a small nudge against the shipping SDK.
  Xcode autocomplete will confirm the correct signatures. This is the single
  most likely place to need a fix.
- **`FoundationModels` availability enums** (`AppleFoundationEngine.swift`) —
  same caveat; verify the `UnavailableReason` cases against the SDK.
- **Default model IDs** (`claude-sonnet-5`, `gpt-4o`) are placeholders and are
  **user-editable in Settings** — set the current model id for your account.
- It has **not been compiled** (authored outside Xcode). Expect a short
  round of "fix-up" build errors, mostly around the two new frameworks above.
- **No tests yet**, no iCloud sync yet, no playback scrubber yet — those are
  Phase 2.

None of these are architectural; they're the expected last mile of adopting
brand-new OS frameworks.

---

## Roadmap

- **Phase 1:** record → on-device transcript → summarize with a pluggable brain
  → local library, editable templates, BYO key. ✅ built
- **Phase 2:** audio playback + scrub, "ask your notes" chat, speaker-labeling
  template, Markdown/web export, Siri Shortcuts, iCloud-sync-ready store. ✅ built
- **Phase 3:** one-time vertical template packs (sales, clinical, journalism) via
  StoreKit 2, first-run onboarding, app icon, App Store listing kit. ✅ built

### Turning on the paid parts

- **StoreKit packs:** the product IDs live in `Store/VerticalPacks.swift` and
  `Murmur.storekit`. To test in Xcode: Edit Scheme ▸ Run ▸ Options ▸ StoreKit
  Configuration ▸ `Murmur.storekit`. For real sales, recreate the same
  non-consumable product IDs in App Store Connect.
- **iCloud sync:** flip `SharedStore.enableCloudSync` to `true` and add the
  iCloud + CloudKit capability (needs a paid Apple Developer account).
- **Siri/Shortcuts:** the App Intents in `Intents/` register automatically; try
  "Summarize my last recording" in the Shortcuts app after first launch.

## Business model

One-time App Store purchase. No subscription, no servers to run, no per-token
cost to the seller — the buyer uses the free on-device model or their own AI
key. Optional future revenue: paid vertical template packs (in-app purchase),
not recurring access.

---

_Working name. Transcription is on-device; summaries use the AI provider the
user configures. Murmur has no backend and collects no user data._
