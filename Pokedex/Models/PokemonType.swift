/// The 18 Pokémon types. Raw values match PokéAPI type names.
enum PokemonType: String, CaseIterable, Hashable, Sendable {
    case normal, fire, water, grass, electric, ice, fighting, poison, ground
    case flying, psychic, bug, rock, ghost, dragon, dark, steel, fairy
}
