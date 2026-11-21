import Foundation

/// A Pokémon the user marked as favorite. Keeps what the favorites list shows,
/// so the list works without a connection.
struct Favorite: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    /// Ordered by slot: the first type is the primary one.
    let types: [PokemonType]
    let addedAt: Date
}

extension Favorite {
    init(_ pokemon: Pokemon, addedAt: Date) {
        self.init(id: pokemon.id, name: pokemon.name, types: pokemon.types, addedAt: addedAt)
    }
}
