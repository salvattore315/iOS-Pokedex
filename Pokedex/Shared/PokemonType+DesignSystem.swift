import DesignSystem

extension PokemonType {
    /// Both enums use the PokéAPI names as raw values, so the mapping cannot fail.
    var tint: TypeTint { TypeTint(rawValue: rawValue) ?? .normal }

    var displayName: String { rawValue.capitalized }

    var badge: TypeBadge { TypeBadge(label: displayName, tint: tint) }
}
