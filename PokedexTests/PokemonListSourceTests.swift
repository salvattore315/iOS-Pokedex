import Testing
@testable import Pokedex

struct LocalListSourceTests {
    private let service = MockPokemonService()

    private func makeSource() throws -> LocalListSource {
        LocalListSource(service: service, store: try makeInMemoryStore())
    }

    @Test func downloadsIndexOnceAndPagesFromStore() async throws {
        service.index = .success(.sample(count: 70))
        let source = try makeSource()

        let first = try await source.page(matching: ListFilter(), offset: 0, limit: 30)
        service.index = .failure(.offline)
        let last = try await source.page(matching: ListFilter(), offset: 60, limit: 30)

        #expect(first.items.map(\.id) == Array(1...30))
        #expect(first.nextOffset == 30)
        #expect(last.items.map(\.id) == Array(61...70))
        #expect(last.nextOffset == nil)
        #expect(service.indexCalls == 1)
    }

    @Test func filtersByNameNumberAndIDs() async throws {
        service.index = .success([
            PokemonSummary(id: 1, name: "bulbasaur"),
            PokemonSummary(id: 4, name: "charmander"),
            PokemonSummary(id: 5, name: "charmeleon"),
            PokemonSummary(id: 25, name: "pikachu"),
        ])
        let source = try makeSource()

        let byName = try await source.page(matching: ListFilter(name: "charm"), offset: 0, limit: 30)
        let byNumber = try await source.page(matching: ListFilter(number: 25), offset: 0, limit: 30)
        let byIDs = try await source.page(matching: ListFilter(name: "char", ids: [5, 25]), offset: 0, limit: 30)

        #expect(byName.items.map(\.id) == [4, 5])
        #expect(byNumber.items.map(\.id) == [25])
        #expect(byIDs.items.map(\.id) == [5])
    }

    @Test func hidesAlternateFormsWhenBrowsing() async throws {
        service.index = .success([PokemonSummary(id: 6, name: "charizard"), PokemonSummary(id: 10034, name: "charizard-mega-x")])
        let page = try await makeSource().page(matching: ListFilter(), offset: 0, limit: 30)
        #expect(page.items.map(\.id) == [6])
    }

    @Test func propagatesNetworkErrorWhenStoreIsEmpty() async throws {
        service.index = .failure(.offline)
        let source = try makeSource()
        await #expect(throws: AppError.offline) {
            try await source.page(matching: ListFilter(), offset: 0, limit: 30)
        }
    }
}

struct RemoteListSourceTests {
    private let service = MockPokemonService()

    private func makeSource() throws -> RemoteListSource {
        RemoteListSource(service: service, local: LocalListSource(service: service, store: try makeInMemoryStore()))
    }

    @Test func browsesWithAPIPages() async throws {
        service.index = .success(.sample(count: 70))
        let page = try await makeSource().page(matching: ListFilter(), offset: 30, limit: 30)
        #expect(page.items.map(\.id) == Array(31...60))
        #expect(service.pageCalls == 1)
        #expect(service.indexCalls == 0)
    }

    @Test func stopsWhenAlternateFormsStart() async throws {
        service.index = .success(.sample(count: 2) + [PokemonSummary(id: 10001, name: "form"), PokemonSummary(id: 10002, name: "form-2")])
        let page = try await makeSource().page(matching: ListFilter(), offset: 0, limit: 3)
        #expect(page.items.map(\.id) == [1, 2])
        #expect(page.nextOffset == nil)
    }

    @Test func usesLocalIndexWhenFiltering() async throws {
        service.index = .success(.sample(count: 70))
        let page = try await makeSource().page(matching: ListFilter(name: "pokemon-42"), offset: 0, limit: 30)
        #expect(page.items.map(\.id) == [42])
        #expect(service.pageCalls == 0)
    }
}
