import Foundation
import Observation

/// Drives the list screen: asks the source for pages, applies search and filters, and loads
/// the next page when the last card appears.
@MainActor
@Observable
final class PokemonListViewModel {
    static let pageSize = 30

    private(set) var state: ViewState<[PokemonSummary]> = .idle
    private(set) var isLoadingMore = false
    /// Types per Pokémon, filled in as cards appear.
    private(set) var types: [Int: [PokemonType]] = [:]

    var query = ""
    private(set) var selectedType: PokemonType?
    private(set) var selectedGeneration: Generation?

    private let source: any PokemonListSource
    private let service: any PokemonService

    private var items: [PokemonSummary] = []
    private var filter = ListFilter()
    private var nextOffset: Int?
    /// Bumped on every reload so answers to older requests are dropped.
    private var requestID = 0
    private var typeIDs: [PokemonType: Set<Int>] = [:]
    private var generationIDs: [Generation: Set<Int>] = [:]
    private var typesInFlight: Set<Int> = []

    init(source: any PokemonListSource, service: any PokemonService) {
        self.source = source
        self.service = service
    }

    // MARK: - Loading

    func load() async {
        await reload()
    }

    func retry() async {
        await reload()
    }

    /// Recomputes the filter from the query and selections and loads the first page.
    func applyFilters() async {
        await reload()
    }

    /// Loads the next page when `item` is the last loaded card.
    func loadMoreIfNeeded(after item: PokemonSummary) async {
        guard item.id == items.last?.id, let offset = nextOffset, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let id = requestID
        // A failed page leaves the list as it is; scrolling to the end again retries it.
        guard let page = try? await source.page(matching: filter, offset: offset, limit: Self.pageSize),
              id == requestID else { return }
        items += page.items
        nextOffset = page.nextOffset
        state = .loaded(items)
    }

    /// Fetches the types of one Pokémon for its card. Failures leave the card without badges.
    func loadTypes(for id: Int) async {
        guard types[id] == nil, !typesInFlight.contains(id) else { return }
        typesInFlight.insert(id)
        defer { typesInFlight.remove(id) }
        if let pokemon = try? await service.pokemon(id: id) {
            types[id] = pokemon.types
        }
    }

    // MARK: - Filters

    func select(type: PokemonType?) async {
        selectedType = type
        await reload()
    }

    func select(generation: Generation?) async {
        selectedGeneration = generation
        await reload()
    }

    // MARK: - Private

    private func reload() async {
        requestID += 1
        let id = requestID
        state = .loading
        do throws(AppError) {
            let typeSet = try await ids(for: selectedType)
            let generationSet = try await ids(for: selectedGeneration)
            let filter = BuildListFilter.make(query: query, typeIDs: typeSet, generationIDs: generationSet)
            let page = try await source.page(matching: filter, offset: 0, limit: Self.pageSize)
            guard id == requestID else { return }
            self.filter = filter
            items = page.items
            nextOffset = page.nextOffset
            state = items.isEmpty ? .empty : .loaded(items)
        } catch {
            guard id == requestID else { return }
            state = .failed(error)
        }
    }

    private func ids(for type: PokemonType?) async throws(AppError) -> Set<Int>? {
        guard let type else { return nil }
        if let cached = typeIDs[type] { return cached }
        let ids = try await service.pokemonIDs(ofType: type)
        typeIDs[type] = ids
        return ids
    }

    private func ids(for generation: Generation?) async throws(AppError) -> Set<Int>? {
        guard let generation else { return nil }
        if let cached = generationIDs[generation] { return cached }
        let ids = try await service.speciesIDs(inGeneration: generation.rawValue)
        generationIDs[generation] = ids
        return ids
    }
}
