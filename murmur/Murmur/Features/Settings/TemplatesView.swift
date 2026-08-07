import SwiftUI
import SwiftData

/// Manage the template library — Murmur's edge over a fixed device. Users can
/// tweak a built-in prompt, clone it, or write their own in plain English.
struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SummaryTemplate.sortIndex) private var templates: [SummaryTemplate]
    @State private var editing: SummaryTemplate?

    var body: some View {
        List {
            ForEach(templates) { template in
                Button {
                    editing = template
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: template.symbol).foregroundStyle(Theme.coral).frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name).font(.headline).tint(.primary)
                            Text(template.isBuiltIn ? "Built-in · tap to edit" : "Custom")
                                .font(Theme.mono(11)).foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let new = SummaryTemplate(
                        name: "New template",
                        symbol: "sparkles",
                        instructions: "Describe how you want this transcript summarized…",
                        isBuiltIn: false,
                        sortIndex: (templates.map(\.sortIndex).max() ?? 0) + 1
                    )
                    context.insert(new)
                    try? context.save()
                    editing = new
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { template in
            TemplateEditor(template: template)
        }
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { context.delete(templates[i]) }
        try? context.save()
    }
}

private struct TemplateEditor: View {
    @Bindable var template: SummaryTemplate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $template.name)
                }
                Section {
                    TextEditor(text: $template.instructions)
                        .frame(minHeight: 240)
                        .font(.body)
                } header: {
                    Text("Instructions")
                } footer: {
                    Text("Plain English. Describe the sections, tone, and format you want. The transcript is added automatically when you run it.")
                }
            }
            .navigationTitle(template.isBuiltIn ? "Edit built-in" : "Edit template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { try? context.save(); dismiss() }
                }
            }
        }
    }
}
