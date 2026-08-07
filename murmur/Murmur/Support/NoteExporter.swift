import Foundation

/// Turns a recording into shareable artifacts: a Markdown document (paste
/// anywhere) and a self-contained styled HTML page (a "share your notes" link
/// the recipient can open in any browser). No cloud involved — the file is
/// written locally and handed to the iOS share sheet.
enum NoteExporter {

    static func markdown(for recording: Recording) -> String {
        var out = "# \(recording.title)\n\n"
        out += "_\(recording.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(recording.duration.clockString)_\n\n"

        for summary in recording.summaries.sorted(by: { $0.createdAt > $1.createdAt }) {
            out += "## \(summary.templateName)\n\n"
            out += summary.content + "\n\n"
            out += "> _\(summary.engineName)_\n\n"
        }

        out += "## Transcript\n\n"
        out += recording.transcript.isEmpty ? "_No transcript._\n" : recording.transcript + "\n"
        return out
    }

    /// Write a standalone HTML page to a temp file and return its URL for sharing.
    static func htmlFileURL(for recording: Recording) throws -> URL {
        let html = htmlDocument(for: recording)
        let safeName = recording.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName).html")
        try html.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private static func htmlDocument(for recording: Recording) -> String {
        let summaries = recording.summaries.sorted { $0.createdAt > $1.createdAt }
        let summaryHTML = summaries.map { s in
            """
            <section class="card">
              <h2>\(escape(s.templateName))</h2>
              <div class="body">\(paragraphs(s.content))</div>
              <p class="attrib">\(escape(s.engineName))</p>
            </section>
            """
        }.joined(separator: "\n")

        return """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(recording.title))</title>
        <style>
          :root { --coral:#D9482F; --ink:#191A1E; --muted:#6C6860; --paper:#FBFAF8; --card:#fff; --border:#E6E1D8; }
          @media (prefers-color-scheme: dark){ :root{ --coral:#FF6A52; --ink:#EEEBE5; --muted:#A6A29A; --paper:#131418; --card:#1A1C22; --border:#2A2E37; } }
          * { box-sizing:border-box; }
          body { margin:0; background:var(--paper); color:var(--ink); font:16px/1.6 -apple-system,system-ui,sans-serif; }
          .wrap { max-width:720px; margin:0 auto; padding:40px 22px 80px; }
          h1 { font-size:30px; letter-spacing:-.02em; margin:0 0 4px; }
          .meta { font:13px ui-monospace,monospace; color:var(--muted); margin-bottom:28px; }
          .card { background:var(--card); border:1px solid var(--border); border-radius:14px; padding:22px; margin:0 0 18px; }
          .card h2 { font-size:18px; margin:0 0 12px; }
          .attrib { font:11px ui-monospace,monospace; color:var(--muted); margin:12px 0 0; }
          .transcript { white-space:pre-wrap; }
          .dot { display:inline-block; width:9px; height:9px; border-radius:50%; background:var(--coral); margin-right:7px; }
          footer { font:12px ui-monospace,monospace; color:var(--muted); text-align:center; margin-top:30px; }
        </style></head><body><div class="wrap">
          <h1><span class="dot"></span>\(escape(recording.title))</h1>
          <div class="meta">\(escape(recording.createdAt.formatted(date: .abbreviated, time: .shortened))) · \(recording.duration.clockString)</div>
          \(summaryHTML)
          <section class="card">
            <h2>Transcript</h2>
            <div class="transcript body">\(escape(recording.transcript))</div>
          </section>
          <footer>Made with Murmur · transcribed on-device</footer>
        </div></body></html>
        """
    }

    private static func paragraphs(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "<p>\(escape(String($0)))</p>" }
            .joined()
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
