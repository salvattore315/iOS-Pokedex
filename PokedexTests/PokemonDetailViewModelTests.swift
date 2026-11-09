import Foundation
import Testing
@testable import Pokedex

@MainActor
struct PokemonDetailViewModelTests {
    private static let chainURL = URL(string: "https://pokeapi.co/api/v2/evolution-chain/1/")!

    private static let bulbasaur = Pokemon(
        id: 1, name: "bulbasaur", types: [.grass, .poison],
        heightInMeters: 0.7, weightInKilograms: 6.9, stats: [],
        artworkURL: nil, cryURL: nil, speciesID: 1
    )

    private static let chain = EvolutionNode(
        speciesID: 1, name: "bulbasaur", minLevel: nil,
        evolvesTo: [EvolutionNode(speciesID: 2, name: "ivysaur", minLevel: 16, evolvesTo: [])]
    )

    private func makeViewModel(_ service: DetailStubService, weaknesses: Result<[Weakness], AppError> = .success([])) -> PokemonDetailViewModel {
        PokemonDetailViewModel(id: 1, service: service, calculateWeaknesses: StubWeaknesses(result: weaknesses))
    }

    @Test func loadsEverySection() async {
        let service = DetailStubService(
            pokemon: .success(Self.bulbasaur),
            species: .success(PokemonSpecies(id: 1, flavorText: "Seed", genus: "Seed Pokémon", evolutionChainURL: Self.chainURL)),
            chain: .success(Self.chain),
            encounters: .success([Encounter(locationArea: "viridian-forest-area", versions: ["red"], methods: ["walk"])])
        )
        let weakness = Weakness(type: .fire, multiplier: 2)
        let viewModel = makeViewModel(service, weaknesses: .success([weakness]))

        await viewModel.load()

        #expect(viewModel.pokemon == .loaded(Self.bulbasaur))
        #expect(viewModel.species.value?.genus == "Seed Pokémon")
        #expect(viewModel.evolutions.value?.map(\.name) == ["bulbasaur", "ivysaur"])
        #expect(viewModel.weaknesses == .loaded([weakness]))
        #expect(viewModel.encounters.value?.count == 1)
    }

    @Test func failsWholeScreenWhenPokemonFails() async {
        let viewModel = makeViewModel(DetailStubService(pokemon: .failure(.offline)))
        await viewModel.load()
        #expect(viewModel.pokemon == .failed(.offline))
        #expect(viewModel.encounters == .idle)
    }

    @Test func sectionFailuresStayInTheirSection() async {
        let service = DetailStubService(
            pokemon: .success(Self.bulbasaur),
            species: .failure(.server),
            encounters: .failure(.offline)
        )
        let viewModel = makeViewModel(service, weaknesses: .failure(.server))

        await viewModel.load()

        #expect(viewModel.pokemon == .loaded(Self.bulbasaur))
        #expect(viewModel.species == .failed(.server))
        #expect(viewModel.evolutions == .failed(.server))
        #expect(viewModel.weaknesses == .failed(.server))
        #expect(viewModel.encounters == .failed(.offline))
    }

    @Test func singleStageChainIsEmpty() async {
        let service = DetailStubService(
            pokemon: .success(Self.bulbasaur),
            species: .success(PokemonSpecies(id: 1, flavorText: nil, genus: nil, evolutionChainURL: Self.chainURL)),
            chain: .success(EvolutionNode(speciesID: 1, name: "bulbasaur", minLevel: nil, evolvesTo: []))
        )
        let viewModel = makeViewModel(service)
        await viewModel.load()
        #expect(viewModel.evolutions == .empty)
        #expect(viewModel.encounters == .empty)
        #expect(viewModel.weaknesses == .empty)
    }
}

/// ``PokemonService`` with one canned answer per detail request.
private struct DetailStubService: PokemonService {
    var pokemon: Result<Pokemon, AppError>
    var species: Result<PokemonSpecies, AppError> = .failure(.notFound)
    var chain: Result<EvolutionNode, AppError> = .failure(.notFound)
    var encounters: Result<[Encounter], AppError> = .success([])

    func pokemon(id: Int) async throws(AppError) -> Pokemon { try pokemon.get() }
    func species(id: Int) async throws(AppError) -> PokemonSpecies { try species.get() }
    func evolutionChain(url: URL) async throws(AppError) -> EvolutionNode { try chain.get() }
    func encounters(pokemonID: Int) async throws(AppError) -> [Encounter] { try encounters.get() }

    func pokemonIndex() async throws(AppError) -> [PokemonSummary] { throw .unexpected }
    func pokemonPage(offset: Int, limit: Int) async throws(AppError) -> Page<PokemonSummary> { throw .unexpected }
    func damageRelations(for type: PokemonType) async throws(AppError) -> TypeDamageRelations { throw .unexpected }
    func pokemonIDs(ofType type: PokemonType) async throws(AppError) -> Set<Int> { throw .unexpected }
    func speciesIDs(inGeneration id: Int) async throws(AppError) -> Set<Int> { throw .unexpected }
}

private struct StubWeaknesses: CalculateWeaknessesUseCase {
    let result: Result<[Weakness], AppError>

    func execute(for types: [PokemonType]) async throws(AppError) -> [Weakness] { try result.get() }
}
