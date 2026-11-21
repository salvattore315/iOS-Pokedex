import Foundation

/// The places a Pokémon can be found in one region.
struct RegionLocations: Hashable, Sendable {
    /// PokéAPI region slug, for example "kanto". `nil` when the region could not be resolved.
    let region: String?
    /// In the order the API returned them.
    let encounters: [Encounter]
}

/// Groups encounters by region. PokéAPI has no direct link from a location area to its
/// region, so each area is resolved in two steps: location area → location → region.
protocol GroupLocationsByRegionUseCase: Sendable {
    /// Never fails: encounters whose region cannot be resolved go to a group with a `nil` region.
    func execute(_ encounters: [Encounter]) async -> [RegionLocations]
}

struct DefaultGroupLocationsByRegionUseCase: GroupLocationsByRegionUseCase {
    /// Regions in game order. Groups follow this order; unknown slugs go after them, alphabetically.
    static let regionOrder = ["kanto", "johto", "hoenn", "sinnoh", "unova", "kalos", "alola", "galar", "hisui", "paldea"]

    private let service: any PokemonService
    private let cache: RegionCache

    /// - Parameter cache: Keeps resolved regions between calls. Share one instance across screens.
    init(service: any PokemonService, cache: RegionCache = RegionCache()) {
        self.service = service
        self.cache = cache
    }

    func execute(_ encounters: [Encounter]) async -> [RegionLocations] {
        let regions = await resolveAtLowPriority(Set(encounters.map(\.locationArea)))

        var groups: [String?: [Encounter]] = [:]
        for encounter in encounters {
            groups[regions[encounter.locationArea], default: []].append(encounter)
        }
        return groups
            .map { RegionLocations(region: $0.key, encounters: $0.value) }
            .sorted { Self.sortKey($0.region) < Self.sortKey($1.region) }
    }

    /// Resolves the region of every area at low priority: these requests only label a section,
    /// so the request limiter serves the rest of the screen first.
    ///
    /// Child tasks and awaited tasks are raised to the priority of whoever waits for them, so the
    /// work runs in a detached task and its result comes back through a stream, which does not
    /// raise it. Cancelling the caller cancels the work.
    private func resolveAtLowPriority(_ areas: Set<String>) async -> [String: String] {
        guard !areas.isEmpty else { return [:] }
        let (stream, continuation) = AsyncStream.makeStream(of: [String: String].self)
        let work = Task.detached(priority: .low) {
            let regions = await withTaskGroup(of: (String, String?).self) { group in
                for area in areas {
                    group.addTask { (area, await region(ofArea: area)) }
                }
                var regions: [String: String] = [:]
                for await (area, region) in group {
                    regions[area] = region
                }
                return regions
            }
            continuation.yield(regions)
            continuation.finish()
        }
        return await withTaskCancellationHandler {
            var result: [String: String] = [:]
            for await regions in stream { result = regions }
            return result
        } onCancel: {
            work.cancel()
            continuation.finish()
        }
    }

    /// `nil` if any step fails or the location belongs to no region.
    private func region(ofArea area: String) async -> String? {
        let location: String
        if let cached = await cache.location(ofArea: area) {
            location = cached
        } else {
            guard let loaded = try? await service.locationName(ofArea: area) else { return nil }
            await cache.store(location: loaded, ofArea: area)
            location = loaded
        }
        if let cached = await cache.region(ofLocation: location) {
            return cached
        }
        guard let region = try? await service.regionName(ofLocation: location) else { return nil }
        await cache.store(region: region, ofLocation: location)
        return region
    }

    /// Known regions first, in game order; then other slugs alphabetically; the unknown group last.
    private static func sortKey(_ region: String?) -> (Int, String) {
        guard let region else { return (Int.max, "") }
        return (regionOrder.firstIndex(of: region) ?? regionOrder.count, region)
    }
}

/// Session cache for region lookups. Only successful answers are kept, so failures are retried
/// the next time a detail screen asks.
actor RegionCache {
    private var locations: [String: String] = [:]
    private var regions: [String: String] = [:]

    init() {}

    func location(ofArea area: String) -> String? { locations[area] }
    func store(location: String, ofArea area: String) { locations[area] = location }

    func region(ofLocation location: String) -> String? { regions[location] }
    func store(region: String?, ofLocation location: String) {
        // A location without a region is rare and cheap to ask again; only real regions are kept.
        if let region { regions[location] = region }
    }
}
