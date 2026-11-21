import Foundation
import Testing
import Networking
@testable import Pokedex

struct FixtureHTTPClientTests {
    @Test(arguments: [
        ("https://pokeapi.co/api/v2/pokemon?offset=0&limit=2000", "pokemon"),
        ("https://pokeapi.co/api/v2/pokemon/1", "pokemon_1"),
        ("https://pokeapi.co/api/v2/pokemon/1/encounters", "pokemon_1_encounters"),
        ("https://pokeapi.co/api/v2/evolution-chain/1/", "evolution-chain_1"),
    ])
    func namesFixturesAfterThePath(url: String, name: String) {
        #expect(FixtureHTTPClient.name(for: URL(string: url)!) == name)
    }

    @Test func answersFromFixturesAndFailsWithoutOne() async throws {
        let client = FixtureHTTPClient(fixtures: ["pokemon_1": #"{"id": 1}"#])
        let data = try await client.data(for: PokeAPIEndpoint.pokemon(id: 1))
        #expect(String(decoding: data, as: UTF8.self) == #"{"id": 1}"#)

        await #expect(throws: APIError.self) {
            _ = try await client.data(for: PokeAPIEndpoint.pokemon(id: 4))
        }
    }
}
