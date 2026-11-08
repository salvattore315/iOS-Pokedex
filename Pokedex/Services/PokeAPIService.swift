import Foundation
import Networking

/// ``PokemonService`` backed by the PokéAPI REST endpoints.
struct PokeAPIService: PokemonService {
    /// PokéAPI returns about 1,350 entries; this limit fetches them all in one request.
    static let indexLimit = 2000

    private let client: any HTTPClient
    private let languageCode: String

    /// - Parameters:
    ///   - client: Performs the requests. Inject a mock in tests.
    ///   - languageCode: Preferred language for species texts. Defaults to the device language.
    init(client: any HTTPClient, languageCode: String = Locale.current.language.languageCode?.identifier ?? "en") {
        self.client = client
        self.languageCode = languageCode
    }

    func pokemonIndex() async throws(AppError) -> [PokemonSummary] {
        try await pokemonPage(offset: 0, limit: Self.indexLimit).items
    }

    func pokemonPage(offset: Int, limit: Int) async throws(AppError) -> Page<PokemonSummary> {
        let dto: PokemonListDTO = try await get(PokeAPIEndpoint.pokemonList(offset: offset, limit: limit))
        return dto.toPage(offset: offset)
    }

    func pokemon(id: Int) async throws(AppError) -> Pokemon {
        let dto: PokemonDTO = try await get(PokeAPIEndpoint.pokemon(id: id))
        return dto.toDomain()
    }

    func species(id: Int) async throws(AppError) -> PokemonSpecies {
        let dto: PokemonSpeciesDTO = try await get(PokeAPIEndpoint.species(id: id))
        return dto.toDomain(languageCode: languageCode)
    }

    func evolutionChain(url: URL) async throws(AppError) -> EvolutionNode {
        let dto: EvolutionChainDTO = try await get(URLEndpoint(url))
        guard let chain = dto.toDomain() else { throw .unexpected }
        return chain
    }

    func encounters(pokemonID: Int) async throws(AppError) -> [Encounter] {
        let dtos: [EncounterDTO] = try await get(PokeAPIEndpoint.encounters(pokemonID: pokemonID))
        return dtos.map { $0.toDomain() }
    }

    func damageRelations(for type: PokemonType) async throws(AppError) -> TypeDamageRelations {
        let dto: TypeDTO = try await get(PokeAPIEndpoint.type(type))
        return dto.toDamageRelations()
    }

    func pokemonIDs(ofType type: PokemonType) async throws(AppError) -> Set<Int> {
        let dto: TypeDTO = try await get(PokeAPIEndpoint.type(type))
        return dto.pokemonIDs
    }

    func speciesIDs(inGeneration id: Int) async throws(AppError) -> Set<Int> {
        let dto: GenerationDTO = try await get(PokeAPIEndpoint.generation(id: id))
        return dto.speciesIDs
    }

    /// Sends the request and converts transport errors into ``AppError``.
    private func get<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws(AppError) -> T {
        do {
            return try await client.send(endpoint, as: T.self)
        } catch {
            throw AppError(error)
        }
    }
}
