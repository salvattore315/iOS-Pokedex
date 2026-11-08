/// A type shown on a component: the text to display and its color.
public struct TypeBadge: Hashable, Sendable {
    public let label: String
    public let tint: TypeTint

    public init(label: String, tint: TypeTint) {
        self.label = label
        self.tint = tint
    }
}
