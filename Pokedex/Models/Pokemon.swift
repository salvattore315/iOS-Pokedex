import Foundation

/// A Pokémon as listed in the index and the paginated list: just enough to show and search it.
struct PokemonSummary: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

/// A Pokémon with the data shown on its card and at the top of the detail screen.
struct Pokemon: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    /// Ordered by slot: the first type is the primary one.
    let types: [PokemonType]
    let heightInMeters: Double
    let weightInKilograms: Double
    let stats: [Stat]
    let artworkURL: URL?
    /// Ogg Vorbis file. Native playback needs iOS 18.4 or later.
    let cryURL: URL?
    let speciesID: Int
}

/// One base stat.
struct Stat: Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case hp
        case attack
        case defense
        case specialAttack = "special-attack"
        case specialDefense = "special-defense"
        case speed
    }

    let kind: Kind
    let value: Int
}

/// A page of results from a paginated endpoint.
struct Page<Item: Sendable>: Sendable {
    let items: [Item]
    let totalCount: Int
    /// `nil` when this is the last page.
    let nextOffset: Int?
}
