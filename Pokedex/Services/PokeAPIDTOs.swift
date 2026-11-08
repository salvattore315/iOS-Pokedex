import Foundation

// Decodable types shaped exactly like PokéAPI responses.
// Keys are decoded with `.convertFromSnakeCase`, so `base_stat` maps to `baseStat`.
// Only the mappers in PokeAPIMappers.swift read these types.

struct NamedAPIResourceDTO: Decodable, Sendable {
    let name: String
    let url: URL

    /// The numeric ID at the end of the resource URL, for example 25 in `/pokemon/25/`.
    var id: Int? { Int(url.lastPathComponent) }
}

struct PokemonListDTO: Decodable, Sendable {
    let count: Int
    let next: URL?
    let results: [NamedAPIResourceDTO]
}

struct PokemonDTO: Decodable, Sendable {
    struct TypeSlot: Decodable, Sendable {
        let slot: Int
        let type: NamedAPIResourceDTO
    }

    struct StatEntry: Decodable, Sendable {
        let baseStat: Int
        let stat: NamedAPIResourceDTO
    }

    struct Sprites: Decodable, Sendable {
        struct Other: Decodable, Sendable {
            let officialArtwork: Artwork?

            enum CodingKeys: String, CodingKey {
                case officialArtwork = "official-artwork"
            }
        }

        struct Artwork: Decodable, Sendable {
            let frontDefault: URL?
        }

        let other: Other?
    }

    struct Cries: Decodable, Sendable {
        let latest: URL?
        let legacy: URL?
    }

    let id: Int
    let name: String
    /// Decimetres.
    let height: Int
    /// Hectograms.
    let weight: Int
    let types: [TypeSlot]
    let stats: [StatEntry]
    let sprites: Sprites
    let cries: Cries?
    let species: NamedAPIResourceDTO
}

struct PokemonSpeciesDTO: Decodable, Sendable {
    struct FlavorTextEntry: Decodable, Sendable {
        let flavorText: String
        let language: NamedAPIResourceDTO
    }

    struct Genus: Decodable, Sendable {
        let genus: String
        let language: NamedAPIResourceDTO
    }

    struct EvolutionChainLink: Decodable, Sendable {
        let url: URL
    }

    let id: Int
    let flavorTextEntries: [FlavorTextEntry]
    let genera: [Genus]
    let evolutionChain: EvolutionChainLink?
}

struct EvolutionChainDTO: Decodable, Sendable {
    struct Link: Decodable, Sendable {
        struct Detail: Decodable, Sendable {
            let minLevel: Int?
        }

        let species: NamedAPIResourceDTO
        let evolutionDetails: [Detail]
        let evolvesTo: [Link]
    }

    let chain: Link
}

struct EncounterDTO: Decodable, Sendable {
    struct VersionDetail: Decodable, Sendable {
        struct EncounterDetail: Decodable, Sendable {
            let method: NamedAPIResourceDTO
        }

        let version: NamedAPIResourceDTO
        let encounterDetails: [EncounterDetail]
    }

    let locationArea: NamedAPIResourceDTO
    let versionDetails: [VersionDetail]
}

struct TypeDTO: Decodable, Sendable {
    struct DamageRelations: Decodable, Sendable {
        let doubleDamageFrom: [NamedAPIResourceDTO]
        let halfDamageFrom: [NamedAPIResourceDTO]
        let noDamageFrom: [NamedAPIResourceDTO]
    }

    struct PokemonEntry: Decodable, Sendable {
        let pokemon: NamedAPIResourceDTO
    }

    let damageRelations: DamageRelations
    let pokemon: [PokemonEntry]
}

struct GenerationDTO: Decodable, Sendable {
    let pokemonSpecies: [NamedAPIResourceDTO]
}
