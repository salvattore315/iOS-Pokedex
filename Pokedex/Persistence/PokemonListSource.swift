import Foundation

/// Where the list gets its pages from.
protocol PokemonListSource: Sendable {
    func page(matching filter: ListFilter, offset: Int, limit: Int) async throws(AppError) -> Page<PokemonSummary>
}

/// Which source the app uses. Set it with the launch argument `-listSource remote`; local by default.
enum ListSourceMode: String, Sendable {
    /// Pages come from SwiftData. The index is downloaded once; after that the list works offline.
    case local
    /// Pages come from the PokéAPI list endpoint. Search and filters still use the local index,
    /// because the API cannot filter by name, type or generation.
    case remote

    static var current: ListSourceMode {
        UserDefaults.standard.string(forKey: "listSource").flatMap(ListSourceMode.init) ?? .local
    }
}

/// Pages from the SwiftData index, downloading it the first time.
struct LocalListSource: PokemonListSource {
    private let service: any PokemonService
    private let store: PokemonIndexStore

    init(service: any PokemonService, store: PokemonIndexStore) {
        self.service = service
        self.store = store
    }

    func page(matching filter: ListFilter, offset: Int, limit: Int) async throws(AppError) -> Page<PokemonSummary> {
        try await ensureIndex()
        do {
            return try await store.page(matching: filter, offset: offset, limit: limit)
        } catch {
            throw .unexpected
        }
    }

    private func ensureIndex() async throws(AppError) {
        if let count = try? await store.count(), count > 0 { return }
        let summaries = try await service.pokemonIndex()
        do {
            try await store.replace(with: summaries)
        } catch {
            throw .unexpected
        }
    }
}

/// Pages from the API while browsing; delegates to the local index as soon as a filter is active.
struct RemoteListSource: PokemonListSource {
    private let service: any PokemonService
    private let local: LocalListSource

    init(service: any PokemonService, local: LocalListSource) {
        self.service = service
        self.local = local
    }

    func page(matching filter: ListFilter, offset: Int, limit: Int) async throws(AppError) -> Page<PokemonSummary> {
        guard filter.isEmpty else {
            return try await local.page(matching: filter, offset: offset, limit: limit)
        }
        let page = try await service.pokemonPage(offset: offset, limit: limit)
        let items = page.items.filter { $0.id < ListFilter.maxDefaultFormID }
        // Once alternate forms appear, the API has no more default forms to return.
        let nextOffset = items.count < page.items.count ? nil : page.nextOffset
        return Page(items: items, totalCount: page.totalCount, nextOffset: nextOffset)
    }
}
