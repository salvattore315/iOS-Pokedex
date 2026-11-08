import Foundation
import Networking

/// Every PokéAPI call the app makes. The base URL lives only here.
struct PokeAPIEndpoint: Endpoint {
    static let base = URL(string: "https://pokeapi.co/api/v2")!

    let path: String
    var queryItems: [URLQueryItem] = []

    var baseURL: URL { Self.base }

    static func pokemonList(offset: Int, limit: Int) -> Self {
        Self(path: "pokemon", queryItems: [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    static func pokemon(id: Int) -> Self { Self(path: "pokemon/\(id)") }
    static func species(id: Int) -> Self { Self(path: "pokemon-species/\(id)") }
    static func encounters(pokemonID: Int) -> Self { Self(path: "pokemon/\(pokemonID)/encounters") }
    static func type(_ type: PokemonType) -> Self { Self(path: "type/\(type.rawValue)") }
    static func generation(id: Int) -> Self { Self(path: "generation/\(id)") }
}
