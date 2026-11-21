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

    private static let viridianForest = Encounter(locationArea: "viridian-forest-area", versions: ["red"], methods: ["walk"])

    private static let chain = EvolutionNode(
        speciesID: 1, name: "bulbasaur", minLevel: nil,
        evolvesTo: [EvolutionNode(speciesID: 2, name: "ivysaur", minLevel: 16, evolvesTo: [])]
    )

    private func makeViewModel(_ service: DetailStubService, weaknesses: Result<[Weakness], AppError> = .success([])) -> PokemonDetailViewModel {
        PokemonDetailViewModel(id: 1, service: service, calculateWeaknesses: StubWeaknesses(result: weaknesses), groupLocations: AllInKanto())
    }

    @Test func loadsEverySection() async {
        let service = DetailStubService(
            pokemon: .success(Self.bulbasaur),
            species: .success(PokemonSpecies(id: 1, flavorText: "Seed", genus: "Seed Pokémon", evolutionChainURL: Self.chainURL)),
            chain: .success(Self.chain),
            encounters: .success([Self.viridianForest])
        )
        let weakness = Weakness(type: .fire, multiplier: 2)
        let viewModel = makeViewModel(service, weaknesses: .success([weakness]))

        await viewModel.load()

        #expect(viewModel.pokemon == .loaded(Self.bulbasaur))
        #expect(viewModel.species.value?.genus == "Seed Pokémon")
        #expect(viewModel.evolutions.value?.map(\.name) == ["bulbasaur", "ivysaur"])
        #expect(viewModel.weaknesses == .loaded([weakness]))
        #expect(viewModel.locations.value == [RegionLocations(region: "kanto", encounters: [Self.viridianForest])])
    }

    @Test func failsWholeScreenWhenPokemonFails() async {
        let viewModel = makeViewModel(DetailStubService(pokemon: .failure(.offline)))
        await viewModel.load()
        #expect(viewModel.pokemon == .failed(.offline))
        #expect(viewModel.locations == .idle)
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
        #expect(viewModel.locations == .failed(.offline))
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
        #expect(viewModel.locations == .empty)
        #expect(viewModel.weaknesses == .empty)
    }
}

// MARK: - Retry

extension PokemonDetailViewModelTests {
    @Test func retryRecoversEveryFailedSection() async {
        let service = RecoveringDetailService(
            pokemon: Self.bulbasaur,
            species: PokemonSpecies(id: 1, flavorText: nil, genus: "Seed Pokémon", evolutionChainURL: Self.chainURL),
            chain: Self.chain,
            encounters: [Self.viridianForest]
        )
        let weakness = Weakness(type: .fire, multiplier: 2)
        let weaknesses = RecoveringWeaknesses(result: [weakness])
        let viewModel = PokemonDetailViewModel(id: 1, service: service, calculateWeaknesses: weaknesses, groupLocations: AllInKanto())

        await viewModel.load()
        #expect(viewModel.evolutions == .failed(.offline))
        #expect(viewModel.weaknesses == .failed(.offline))
        #expect(viewModel.locations == .failed(.offline))

        await viewModel.retryEvolutions()
        await viewModel.retryWeaknesses()
        await viewModel.retryLocations()

        #expect(viewModel.species.value?.genus == "Seed Pokémon")
        #expect(viewModel.evolutions.value?.map(\.name) == ["bulbasaur", "ivysaur"])
        #expect(viewModel.weaknesses == .loaded([weakness]))
        #expect(viewModel.locations.value == [RegionLocations(region: "kanto", encounters: [Self.viridianForest])])
    }

    @Test func retryDoesNothingBeforeThePokemonLoads() async {
        let viewModel = makeViewModel(DetailStubService(pokemon: .failure(.offline)))
        await viewModel.load()

        await viewModel.retryEvolutions()
        await viewModel.retryWeaknesses()
        await viewModel.retryLocations()

        #expect(viewModel.evolutions == .idle)
        #expect(viewModel.weaknesses == .idle)
        #expect(viewModel.locations == .idle)
    }
}

/// Fails the first call of each section with `.offline` and answers every later call.
private final class RecoveringDetailService: PokemonService, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [String: Int] = [:]
    private let pokemon: Pokemon
    private let species: PokemonSpecies
    private let chain: EvolutionNode
    private let encounters: [Encounter]

    init(pokemon: Pokemon, species: PokemonSpecies, chain: EvolutionNode, encounters: [Encounter]) {
        self.pokemon = pokemon
        self.species = species
        self.chain = chain
        self.encounters = encounters
    }

    /// Throws on the first call for `key` only.
    private func failFirstCall(_ key: String) throws(AppError) {
        let count = lock.withLock {
            calls[key, default: 0] += 1
            return calls[key]!
        }
        if count == 1 { throw .offline }
    }

    func pokemon(id: Int) async throws(AppError) -> Pokemon { pokemon }
    func species(id: Int) async throws(AppError) -> PokemonSpecies {
        try failFirstCall("species")
        return species
    }
    func evolutionChain(url: URL) async throws(AppError) -> EvolutionNode { chain }
    func encounters(pokemonID: Int) async throws(AppError) -> [Encounter] {
        try failFirstCall("encounters")
        return encounters
    }

    func pokemonIndex() async throws(AppError) -> [PokemonSummary] { throw .unexpected }
    func pokemonPage(offset: Int, limit: Int) async throws(AppError) -> Page<PokemonSummary> { throw .unexpected }
    func damageRelations(for type: PokemonType) async throws(AppError) -> TypeDamageRelations { throw .unexpected }
    func locationName(ofArea area: String) async throws(AppError) -> String { throw .unexpected }
    func regionName(ofLocation location: String) async throws(AppError) -> String? { throw .unexpected }
    func pokemonIDs(ofType type: PokemonType) async throws(AppError) -> Set<Int> { throw .unexpected }
    func speciesIDs(inGeneration id: Int) async throws(AppError) -> Set<Int> { throw .unexpected }
}

/// Fails the first calculation with `.offline` and returns `result` afterwards.
private final class RecoveringWeaknesses: CalculateWeaknessesUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private let result: [Weakness]

    init(result: [Weakness]) { self.result = result }

    func execute(for types: [PokemonType]) async throws(AppError) -> [Weakness] {
        let count = lock.withLock {
            calls += 1
            return calls
        }
        if count == 1 { throw .offline }
        return result
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
    func locationName(ofArea area: String) async throws(AppError) -> String { throw .unexpected }
    func regionName(ofLocation location: String) async throws(AppError) -> String? { throw .unexpected }
    func pokemonIDs(ofType type: PokemonType) async throws(AppError) -> Set<Int> { throw .unexpected }
    func speciesIDs(inGeneration id: Int) async throws(AppError) -> Set<Int> { throw .unexpected }
}

/// Puts every encounter in Kanto.
private struct AllInKanto: GroupLocationsByRegionUseCase {
    func execute(_ encounters: [Encounter]) async -> [RegionLocations] {
        [RegionLocations(region: "kanto", encounters: encounters)]
    }
}

private struct StubWeaknesses: CalculateWeaknessesUseCase {
    let result: Result<[Weakness], AppError>

    func execute(for types: [PokemonType]) async throws(AppError) -> [Weakness] { try result.get() }
}
