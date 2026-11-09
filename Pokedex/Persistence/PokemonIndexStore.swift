import Foundation
import SwiftData

/// Reads and writes the search index on a background context.
@ModelActor
actor PokemonIndexStore {
    func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<PokemonIndexEntry>())
    }

    /// Replaces the whole index with `summaries`.
    func replace(with summaries: [PokemonSummary]) throws {
        try modelContext.delete(model: PokemonIndexEntry.self)
        for summary in summaries {
            modelContext.insert(PokemonIndexEntry(summary))
        }
        try modelContext.save()
    }

    /// One page of entries matching `filter`, sorted by number. Filtering and paging run in the store.
    func page(matching filter: ListFilter, offset: Int, limit: Int) throws -> Page<PokemonSummary> {
        var descriptor = FetchDescriptor(predicate: Self.predicate(for: filter), sortBy: [SortDescriptor(\.id)])
        let total = try modelContext.fetchCount(descriptor)
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        let items = try modelContext.fetch(descriptor).map(\.summary)
        let end = offset + items.count
        return Page(items: items, totalCount: total, nextOffset: end < total ? end : nil)
    }

    private static func predicate(for filter: ListFilter) -> Predicate<PokemonIndexEntry> {
        let anyID = filter.ids == nil
        let ids = Array(filter.ids ?? [])
        if let number = filter.number {
            return #Predicate { $0.id == number && (anyID || ids.contains($0.id)) }
        }
        let maxID = ListFilter.maxDefaultFormID
        let name = filter.name
        let anyName = name.isEmpty
        return #Predicate {
            $0.id < maxID && (anyID || ids.contains($0.id)) && (anyName || $0.name.contains(name))
        }
    }
}
