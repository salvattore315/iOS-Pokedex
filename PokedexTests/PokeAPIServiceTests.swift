import Foundation
import Testing
import Networking
@testable import Pokedex

struct PokeAPIServiceTests {
    private let client = MockHTTPClient()
    private var service: PokeAPIService { PokeAPIService(client: client, languageCode: "en") }

    @Test func loadsPokemon() async throws {
        client.stub("pokemon/1", json: Fixtures.bulbasaur)
        let pokemon = try await service.pokemon(id: 1)
        #expect(pokemon.name == "bulbasaur")
        #expect(client.requestedPaths == ["/api/v2/pokemon/1"])
    }

    @Test func requestsWholeIndexInOneCall() async throws {
        client.stub("pokemon", json: Fixtures.page)
        let index = try await service.pokemonIndex()
        #expect(index.count == 2)
        #expect(client.requestedPaths.count == 1)
    }

    @Test func followsEvolutionChainURL() async throws {
        client.stub("evolution-chain/1", json: Fixtures.bulbasaurChain)
        let chain = try await service.evolutionChain(url: URL(string: "https://pokeapi.co/api/v2/evolution-chain/1/")!)
        #expect(chain.stages.count == 3)
    }

    @Test func convertsTransportErrorsToAppErrors() async {
        client.stub("pokemon/9999", error: .http(statusCode: 404))
        await #expect(throws: AppError.notFound) {
            _ = try await service.pokemon(id: 9999)
        }
        client.stub("pokemon/1", error: .offline)
        await #expect(throws: AppError.offline) {
            _ = try await service.pokemon(id: 1)
        }
    }
}
