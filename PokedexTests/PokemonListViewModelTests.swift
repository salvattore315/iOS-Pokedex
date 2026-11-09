import Testing
@testable import Pokedex

@MainActor
struct PokemonListViewModelTests {
    private let service = MockPokemonService()

    private func makeViewModel(index: Result<[PokemonSummary], AppError> = .success(.sample(count: 70))) throws -> PokemonListViewModel {
        service.index = index
        let source = LocalListSource(service: service, store: try makeInMemoryStore())
        return PokemonListViewModel(source: source, service: service)
    }

    @Test func showsFirstPageAfterLoading() async throws {
        let viewModel = try makeViewModel()
        await viewModel.load()
        #expect(viewModel.state.value?.count == PokemonListViewModel.pageSize)
    }

    @Test func loadsNextPageOnlyFromLastCard() async throws {
        let viewModel = try makeViewModel()
        await viewModel.load()

        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.state.value?.first))
        #expect(viewModel.state.value?.count == 30)

        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.state.value?.last))
        #expect(viewModel.state.value?.count == 60)

        await viewModel.loadMoreIfNeeded(after: try #require(viewModel.state.value?.last))
        #expect(viewModel.state.value?.count == 70)
    }

    @Test func showsErrorWhenIndexFails() async throws {
        let viewModel = try makeViewModel(index: .failure(.offline))
        await viewModel.load()
        #expect(viewModel.state == .failed(.offline))
    }

    @Test func searchesByName() async throws {
        let viewModel = try makeViewModel()
        await viewModel.load()
        viewModel.query = "pokemon-42"
        await viewModel.applyFilters()
        #expect(viewModel.state.value?.map(\.id) == [42])
    }

    @Test func showsEmptyWhenNothingMatches() async throws {
        let viewModel = try makeViewModel()
        await viewModel.load()
        viewModel.query = "missingno"
        await viewModel.applyFilters()
        #expect(viewModel.state == .empty)
    }

    @Test func filtersByTypeAndGeneration() async throws {
        service.typeIDs = [.fire: [4, 5, 6, 37]]
        service.generationIDs = [1: Set(1...151)]
        let viewModel = try makeViewModel()
        await viewModel.load()

        await viewModel.select(type: .fire)
        #expect(viewModel.state.value?.map(\.id) == [4, 5, 6, 37])

        await viewModel.select(generation: .johto)
        #expect(viewModel.state == .empty)

        await viewModel.select(type: nil)
        await viewModel.select(generation: nil)
        #expect(viewModel.state.value?.count == PokemonListViewModel.pageSize)
    }

    @Test func retryRecoversFromFilterFailure() async throws {
        service.typeIDs = [.water: [7, 8, 9]]
        let viewModel = try makeViewModel()
        await viewModel.load()

        service.filterError = .server
        await viewModel.select(type: .water)
        #expect(viewModel.state == .failed(.server))

        service.filterError = nil
        await viewModel.retry()
        #expect(viewModel.state.value?.map(\.id) == [7, 8, 9])
    }

    @Test func loadsCardTypes() async throws {
        service.types = [1: [.grass, .poison]]
        let viewModel = try makeViewModel()
        await viewModel.loadTypes(for: 1)
        await viewModel.loadTypes(for: 2)
        #expect(viewModel.types[1] == [.grass, .poison])
        #expect(viewModel.types[2] == nil)
    }
}
