import Foundation
import SwiftData
@testable import Pokedex

/// ``PokemonService`` with canned answers. Calls the list does not use fail with `.unexpected`.
final class MockPokemonService: PokemonService, @unchecked Sendable {
    private let lock = NSLock()
    private var _index: Result<[PokemonSummary], AppError> = .success([])
    private var _typeIDs: [PokemonType: Set<Int>] = [:]
    private var _generationIDs: [Int: Set<Int>] = [:]
    private var _types: [Int: [PokemonType]] = [:]
    private var _filterError: AppError?
    private var _indexCalls = 0
    private var _pageCalls = 0

    var index: Result<[PokemonSummary], AppError> {
        get { lock.withLock { _index } }
        set { lock.withLock { _index = newValue } }
    }
    var typeIDs: [PokemonType: Set<Int>] {
        get { lock.withLock { _typeIDs } }
        set { lock.withLock { _typeIDs = newValue } }
    }
    var generationIDs: [Int: Set<Int>] {
        get { lock.withLock { _generationIDs } }
        set { lock.withLock { _generationIDs = newValue } }
    }
    var types: [Int: [PokemonType]] {
        get { lock.withLock { _types } }
        set { lock.withLock { _types = newValue } }
    }
    /// When set, type and generation lookups fail with this error.
    var filterError: AppError? {
        get { lock.withLock { _filterError } }
        set { lock.withLock { _filterError = newValue } }
    }
    var indexCalls: Int { lock.withLock { _indexCalls } }
    var pageCalls: Int { lock.withLock { _pageCalls } }

    func pokemonIndex() async throws(AppError) -> [PokemonSummary] {
        lock.withLock { _indexCalls += 1 }
        return try index.get()
    }

    /// Slices ``index`` like the API list endpoint does, alternate forms included.
    func pokemonPage(offset: Int, limit: Int) async throws(AppError) -> Page<PokemonSummary> {
        lock.withLock { _pageCalls += 1 }
        let all = try index.get()
        let items = Array(all.dropFirst(offset).prefix(limit))
        let end = offset + items.count
        return Page(items: items, totalCount: all.count, nextOffset: end < all.count ? end : nil)
    }

    func pokemon(id: Int) async throws(AppError) -> Pokemon {
        guard let types = types[id] else { throw .notFound }
        return Pokemon(
            id: id, name: "pokemon-\(id)", types: types,
            heightInMeters: 1, weightInKilograms: 1, stats: [],
            artworkURL: nil, cryURL: nil, speciesID: id
        )
    }

    func species(id: Int) async throws(AppError) -> PokemonSpecies { throw .unexpected }
    func evolutionChain(url: URL) async throws(AppError) -> EvolutionNode { throw .unexpected }
    func encounters(pokemonID: Int) async throws(AppError) -> [Encounter] { throw .unexpected }
    func damageRelations(for type: PokemonType) async throws(AppError) -> TypeDamageRelations { throw .unexpected }

    func pokemonIDs(ofType type: PokemonType) async throws(AppError) -> Set<Int> {
        if let filterError { throw filterError }
        return typeIDs[type] ?? []
    }

    func speciesIDs(inGeneration id: Int) async throws(AppError) -> Set<Int> {
        if let filterError { throw filterError }
        return generationIDs[id] ?? []
    }
}

extension Array where Element == PokemonSummary {
    /// `count` entries named "pokemon-<id>", IDs starting at 1.
    static func sample(count: Int) -> [PokemonSummary] {
        (1...count).map { PokemonSummary(id: $0, name: "pokemon-\($0)") }
    }
}

/// An empty index store that lives only in memory.
func makeInMemoryStore() throws -> PokemonIndexStore {
    let container = try ModelContainer(
        for: PokemonIndexEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return PokemonIndexStore(modelContainer: container)
}
