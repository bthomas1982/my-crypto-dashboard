import Foundation
import SwiftData

/// A reusable summarization prompt. This is Murmur's core advantage over a fixed
/// device: a template is just plain-English instructions the user can edit, so
/// every future note follows their preferred shape.
@Model
final class SummaryTemplate {
    var id: UUID
    var name: String
    /// SF Symbol name for the row.
    var symbol: String
    /// The instructions handed to whichever brain the user has selected. The
    /// transcript is appended by the engine — this is the "how", not the text.
    var instructions: String
    /// Built-in templates ship with the app; user templates are editable/removable.
    var isBuiltIn: Bool
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String = "doc.text",
        instructions: String,
        isBuiltIn: Bool = false,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.instructions = instructions
        self.isBuiltIn = isBuiltIn
        self.sortIndex = sortIndex
    }
}
