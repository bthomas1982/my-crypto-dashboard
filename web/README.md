# Murmur PWA (browser prototype)

A web version of Murmur you can install on an iPhone home screen — **no Mac, no
App Store needed**. It demonstrates the real flow:

**Record** (in-browser) → **transcribe on-device** with Whisper (WASM, private,
no key) → **summarize / ask** with your own Claude key.

## What this is (and isn't)

This is a **prototype of the experience**, not the shipping app. A web app cannot
use the two native iOS 26 superpowers the real Murmur is built on:

- Apple's on-device `SpeechAnalyzer` (this PWA uses Whisper-WASM instead — slower,
  downloads a ~40 MB model once).
- Apple's free on-device summarization model (this PWA needs your Claude key).

Everything else — capture, private on-device transcription, templates, ask-your-
notes, export — works here so you can feel the product on your phone today.

## Use it

1. Open the site (see the deployed URL) in **Safari** on your iPhone.
2. Share ▸ **Add to Home Screen** to install it.
3. Tap **Record**, speak, then **Stop & transcribe** (first run downloads the
   Whisper model — do it on Wi-Fi).
4. Open **⚙︎ Settings**, paste your **Claude API key** and set your model, to
   enable summaries and chat. The key stays in your browser and calls Anthropic
   directly — nothing passes through a server.

## How it's hosted

Static files deployed to GitHub Pages by `.github/workflows/deploy-pwa.yml`.
No backend. Recordings live in your browser (IndexedDB); the API key lives in
localStorage on your device only.
