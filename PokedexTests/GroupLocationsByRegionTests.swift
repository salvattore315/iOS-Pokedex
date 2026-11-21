import Foundation
import Testing
@testable import Pokedex

struct GroupLocationsByRegionTests {
    private static func encounter(_ area: String) -> Encounter {
        Encounter(locationArea: area, versions: ["red"], methods: ["walk"])
    }

    private let service = RegionStubService(
        locations: [
            "pallet-town-area": "pallet-town",
            "route-1-area": "kanto-route-1",
            "route-29-area": "johto-route-29",
            "lake-area": "nameless-lake",
            "broken-area": "broken-location",
        ],
        regions: ["pallet-town": "kanto", "kanto-route-1": "kanto", "johto-route-29": "johto", "nameless-lake": nil]
    )

    @Test func groupsByRegionInGameOrder() async {
        let useCase = DefaultGroupLocationsByRegionUseCase(service: service)

        let groups = await useCase.execute([
            Self.encounter("route-29-area"),
            Self.encounter("pallet-town-area"),
            Self.encounter("route-1-area"),
        ])

        #expect(groups.map(\.region) == ["kanto", "johto"])
        #expect(groups[0].encounters.map(\.locationArea) == ["pallet-town-area", "route-1-area"])
        #expect(groups[1].encounters.map(\.locationArea) == ["route-29-area"])
    }

    @Test func unresolvedAreasGoToTheUnknownGroupLast() async {
        let useCase = DefaultGroupLocationsByRegionUseCase(service: service)

        let groups = await useCase.execute([
            Self.encounter("missing-area"),   // location-area request fails
            Self.encounter("broken-area"),    // location request fails
            Self.encounter("lake-area"),      // location without a region
            Self.encounter("route-1-area"),
        ])

        #expect(groups.map(\.region) == ["kanto", nil])
        #expect(groups[1].encounters.map(\.locationArea) == ["missing-area", "broken-area", "lake-area"])
    }

    @Test func otherRegionsGoAfterTheKnownOnes() async {
        let service = RegionStubService(
            locations: ["a-area": "a", "b-area": "b"],
            regions: ["a": "orre", "b": "kanto"]
        )
        let groups = await DefaultGroupLocationsByRegionUseCase(service: service).execute([Self.encounter("a-area"), Self.encounter("b-area")])
        #expect(groups.map(\.region) == ["kanto", "orre"])
    }

    @Test func noEncountersMeansNoGroups() async {
        let groups = await DefaultGroupLocationsByRegionUseCase(service: service).execute([])
        #expect(groups.isEmpty)
        #expect(service.calls.isEmpty)
    }

    @Test func resolvedRegionsAreCachedAcrossCalls() async {
        let cache = RegionCache()
        let encounters = [Self.encounter("pallet-town-area"), Self.encounter("route-29-area")]

        _ = await DefaultGroupLocationsByRegionUseCase(service: service, cache: cache).execute(encounters)
        let callsAfterFirst = service.calls.count
        let groups = await DefaultGroupLocationsByRegionUseCase(service: service, cache: cache).execute(encounters)

        #expect(callsAfterFirst == 4)
        #expect(service.calls.count == callsAfterFirst)
        #expect(groups.map(\.region) == ["kanto", "johto"])
    }

    @Test func failuresAreNotCached() async {
        let cache = RegionCache()
        let useCase = DefaultGroupLocationsByRegionUseCase(service: service, cache: cache)

        _ = await useCase.execute([Self.encounter("broken-area")])
        _ = await useCase.execute([Self.encounter("broken-area")])

        // The area → location step is cached; the failing location request is retried.
        #expect(service.calls == ["area:broken-area", "location:broken-location", "location:broken-location"])
    }

    @Test func resolvesRegionsAtLowPriority() async {
        // The caller runs at a higher priority; the lookups must not be raised to it.
        _ = await Task(priority: .userInitiated) {
            await DefaultGroupLocationsByRegionUseCase(service: service).execute([Self.encounter("pallet-town-area")])
        }.value
        #expect(service.priorities.allSatisfy { $0 <= .low })
        #expect(service.priorities.count == 2)
    }
}

/// Answers location and region lookups from dictionaries. Unknown keys fail with `.notFound`.
private final class RegionStubService: PokemonService, @unchecked Sendable {
    private let lock = NSLock()
    private let locations: [String: String]
    private let regions: [String: String?]
    private var _calls: [String] = []
    private var _priorities: [TaskPriority] = []

    init(locations: [String: String], regions: [String: String?]) {
        self.locations = locations
        self.regions = regions
    }

    var calls: [String] { lock.withLock { _calls } }
    var priorities: [TaskPriority] { lock.withLock { _priorities } }

    private func record(_ call: String) {
        let priority = Task.currentPriority
        lock.withLock {
            _calls.append(call)
            _priorities.append(priority)
        }
    }

    func locationName(ofArea area: String) async throws(AppError) -> String {
        record("area:\(area)")
        guard let location = locations[area] else { throw .notFound }
        return location
    }

    func regionName(ofLocation location: String) async throws(AppError) -> String? {
        record("location:\(location)")
        guard let region = regions[location] else { throw .notFound }
        return region
    }

    func pokemonIndex() async throws(AppError) -> [PokemonSummary] { throw .unexpected }
    func pokemonPage(offset: Int, limit: Int) async throws(AppError) -> Page<PokemonSummary> { throw .unexpected }
    func pokemon(id: Int) async throws(AppError) -> Pokemon { throw .unexpected }
    func species(id: Int) async throws(AppError) -> PokemonSpecies { throw .unexpected }
    func evolutionChain(url: URL) async throws(AppError) -> EvolutionNode { throw .unexpected }
    func encounters(pokemonID: Int) async throws(AppError) -> [Encounter] { throw .unexpected }
    func damageRelations(for type: PokemonType) async throws(AppError) -> TypeDamageRelations { throw .unexpected }
    func pokemonIDs(ofType type: PokemonType) async throws(AppError) -> Set<Int> { throw .unexpected }
    func speciesIDs(inGeneration id: Int) async throws(AppError) -> Set<Int> { throw .unexpected }
}
