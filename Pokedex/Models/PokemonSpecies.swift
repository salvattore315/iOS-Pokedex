import Foundation

/// Species data for the "About" section and the evolution chain.
struct PokemonSpecies: Identifiable, Hashable, Sendable {
    let id: Int
    /// Description in the user's language, falling back to English.
    let flavorText: String?
    /// Category, for example "Seed Pokémon".
    let genus: String?
    let evolutionChainURL: URL?
}

/// One node of an evolution chain. Branching chains (for example Eevee) have several `evolvesTo`.
struct EvolutionNode: Identifiable, Hashable, Sendable {
    let speciesID: Int
    let name: String
    /// Level needed to reach this stage, when evolution is by level.
    let minLevel: Int?
    let evolvesTo: [EvolutionNode]

    var id: Int { speciesID }

    /// All stages in depth-first order, starting with this one.
    var stages: [EvolutionNode] {
        [self] + evolvesTo.flatMap(\.stages)
    }
}

/// Where a Pokémon can be found in the games.
struct Encounter: Hashable, Sendable {
    /// PokéAPI location area slug, for example "viridian-forest-area".
    let locationArea: String
    /// Game version slugs, for example ["red", "blue"].
    let versions: [String]
    /// Encounter method slugs, for example ["walk", "gift"].
    let methods: [String]
}

/// How much damage a defending type takes from attacking types.
struct TypeDamageRelations: Hashable, Sendable {
    let doubleDamageFrom: Set<PokemonType>
    let halfDamageFrom: Set<PokemonType>
    let noDamageFrom: Set<PokemonType>
}
