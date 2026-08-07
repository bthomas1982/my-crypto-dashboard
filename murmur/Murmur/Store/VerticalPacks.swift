import Foundation

/// A paid, one-time template pack for a specific line of work. This is Phase-3
/// revenue that never becomes a subscription: buy the pack, own the templates.
struct VerticalPack: Identifiable {
    /// Must match the StoreKit product id (see Murmur.storekit / App Store Connect).
    let id: String
    let name: String
    let tagline: String
    let symbol: String
    /// The templates unlocked by buying this pack.
    let templates: [PackTemplate]

    struct PackTemplate {
        let name: String
        let symbol: String
        let instructions: String
    }
}

enum VerticalPacks {
    static let all: [VerticalPack] = [
        VerticalPack(
            id: "com.murmur.pack.sales",
            name: "Sales Calls",
            tagline: "Turn calls into CRM-ready notes and next steps.",
            symbol: "chart.line.uptrend.xyaxis",
            templates: [
                .init(name: "Discovery Call → CRM", symbol: "person.crop.rectangle",
                      instructions: """
                      Summarize this sales discovery call into CRM fields:
                      **Company / Contact**, **Pain points**, **Current solution**, **Budget signals**,
                      **Decision process & timeline**, **Objections**, **Next step (with date)**.
                      Use "—" for anything not discussed. End with a one-line deal-health read.
                      """),
                .init(name: "MEDDIC Qualification", symbol: "checklist.checked",
                      instructions: """
                      Assess this call against MEDDIC. For each — Metrics, Economic buyer, Decision
                      criteria, Decision process, Identify pain, Champion — state what you learned and
                      mark it 🟢 known / 🟡 partial / 🔴 unknown. Finish with the top 2 gaps to close.
                      """),
            ]
        ),
        VerticalPack(
            id: "com.murmur.pack.clinical",
            name: "Therapy & Clinical Notes",
            tagline: "Structured session notes that stay on your device.",
            symbol: "heart.text.square",
            templates: [
                .init(name: "SOAP Note", symbol: "cross.case",
                      instructions: """
                      Produce a SOAP note from this session: **Subjective**, **Objective**,
                      **Assessment**, **Plan**. Be clinical and concise. Only include what was stated;
                      do not infer diagnoses. Add a "Verify before use" reminder at the end.
                      """),
                .init(name: "DAP Progress Note", symbol: "list.clipboard",
                      instructions: """
                      Write a DAP progress note: **Data**, **Assessment**, **Plan**. Neutral clinical
                      tone. Flag any risk statements verbatim under a **Safety** heading if present.
                      """),
            ]
        ),
        VerticalPack(
            id: "com.murmur.pack.journalism",
            name: "Journalism & Research",
            tagline: "Interviews into quotes, facts, and follow-ups.",
            symbol: "newspaper",
            templates: [
                .init(name: "Interview → Quotes & Facts", symbol: "quote.opening",
                      instructions: """
                      From this interview produce: **Key quotes** (verbatim, attributed, timestamped if
                      available), **Factual claims to verify** (as a checklist), **Story angles**, and
                      **Follow-up questions**. Never paraphrase a quote — mark it [paraphrase] if unsure.
                      """),
                .init(name: "Fact-check Worksheet", symbol: "magnifyingglass",
                      instructions: """
                      Extract every checkable factual claim as a table: Claim | Who said it | How to
                      verify | Confidence. List nothing that isn't actually asserted in the transcript.
                      """),
            ]
        ),
    ]

    static func pack(for id: String) -> VerticalPack? { all.first { $0.id == id } }
    static var productIDs: [String] { all.map(\.id) }
}
