import Foundation
import SwiftData

/// The starter set of templates seeded on first launch. These mirror the note
/// shapes people actually want (and that Plaud charges to unlock) — but here
/// they're just editable prompts.
enum BuiltInTemplates {
    static let all: [SummaryTemplate] = [
        SummaryTemplate(
            name: "Meeting Minutes",
            symbol: "person.2.wave.2",
            instructions: """
            You are a precise meeting scribe. From the transcript, produce clean minutes with these sections, each as a Markdown heading. Omit a section only if there is genuinely nothing to put in it.

            ## Summary
            2–3 sentences on what the meeting was about and what it concluded.

            ## Decisions
            Bullet every concrete decision made.

            ## Action Items
            A checklist. For each: the task, the owner if named, and any due date mentioned. Format: "- [ ] Task — Owner (due date)".

            ## Open Questions
            Anything raised but left unresolved.

            Be faithful to the transcript. Do not invent owners or dates that were not said.
            """,
            isBuiltIn: true, sortIndex: 0
        ),
        SummaryTemplate(
            name: "Action Items Only",
            symbol: "checklist",
            instructions: """
            Extract only the action items from this transcript as a Markdown checklist. For each item give the task, the owner (if stated), and the due date (if stated), formatted "- [ ] Task — Owner (due date)". If nothing is actionable, say "No action items found." Do not add commentary.
            """,
            isBuiltIn: true, sortIndex: 1
        ),
        SummaryTemplate(
            name: "Quick Summary",
            symbol: "text.line.first.and.arrowtriangle.forward",
            instructions: """
            Summarize this transcript in 4–6 tight bullet points capturing the key points and any outcome. Plain language. No preamble.
            """,
            isBuiltIn: true, sortIndex: 2
        ),
        SummaryTemplate(
            name: "Interview Notes",
            symbol: "quote.bubble",
            instructions: """
            This is an interview or conversation. Produce:

            ## Themes
            Group the discussion into 3–6 themes, each a short heading with 1–3 bullets underneath capturing what was said.

            ## Notable Quotes
            2–4 direct, verbatim quotes worth keeping, each with the speaker if identifiable.

            ## Follow-ups
            Questions worth asking next time.
            """,
            isBuiltIn: true, sortIndex: 3
        ),
        SummaryTemplate(
            name: "Lecture Notes",
            symbol: "graduationcap",
            instructions: """
            These are notes from a lecture or talk. Produce structured study notes:

            ## Overview
            One paragraph on the topic.

            ## Key Concepts
            The main ideas, each as a bold term followed by a plain-language explanation.

            ## Details & Examples
            Supporting facts, examples, and definitions worth remembering.

            ## Questions to Review
            3–5 self-test questions a student could use to revise.
            """,
            isBuiltIn: true, sortIndex: 4
        ),
        SummaryTemplate(
            name: "Clean Voice Note",
            symbol: "waveform",
            instructions: """
            This is a spoken voice memo — a stream of thought. Rewrite it into clear, well-organized prose that preserves every idea and the speaker's intent, but removes filler ("um", "you know"), false starts, and repetition. Keep it first-person. Add short paragraph breaks. Do not summarize away detail — this is a cleanup, not a summary.
            """,
            isBuiltIn: true, sortIndex: 5
        ),
        SummaryTemplate(
            name: "Follow-up Email",
            symbol: "envelope",
            instructions: """
            Draft a concise, professional follow-up email based on this conversation. Include a subject line, a brief recap, any agreed next steps as a short list, and a friendly close. Leave "[Name]" placeholders where you don't know the recipient. Keep it under 200 words.
            """,
            isBuiltIn: true, sortIndex: 6
        ),
    ]

    /// Seed the built-in templates once. Safe to call on every launch.
    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<SummaryTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        for template in all { context.insert(template) }
        try? context.save()
    }
}
