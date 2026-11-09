/// What the list is narrowed to. An empty filter means "every Pokémon".
struct ListFilter: Equatable, Sendable {
    /// IDs above this are alternate forms (megas, regional variants). Browsing shows default forms only.
    static let maxDefaultFormID = 10_000

    /// Lowercased name fragment. Ignored when `number` is set.
    var name = ""
    /// Exact Pokédex number.
    var number: Int?
    /// Allowed IDs from the type and generation filters, or `nil` when neither is selected.
    var ids: Set<Int>?

    var isEmpty: Bool { name.isEmpty && number == nil && ids == nil }
}
