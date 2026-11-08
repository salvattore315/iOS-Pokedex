import Testing
@testable import Pokedex

struct CalculateWeaknessesTests {
    private func relations(_ json: String) throws -> TypeDamageRelations {
        try decodeFixture(TypeDTO.self, json).toDamageRelations()
    }

    @Test func grassPoisonMatchesTheDesign() throws {
        // Bulbasaur: fire, ice, flying and psychic ×2. Poison (×2 from grass, ×0.5 from poison) cancels out.
        let weaknesses = WeaknessCalculator.weaknesses(from: [try relations(Fixtures.grassType), try relations(Fixtures.poisonType)])
        #expect(Set(weaknesses.map(\.type)) == [.fire, .ice, .flying, .psychic])
        #expect(weaknesses.allSatisfy { $0.multiplier == 2 })
    }

    @Test func doubleWeaknessStacksToFour() {
        let rel = TypeDamageRelations(doubleDamageFrom: [.ice], halfDamageFrom: [], noDamageFrom: [])
        let weaknesses = WeaknessCalculator.weaknesses(from: [rel, rel])
        #expect(weaknesses == [Weakness(type: .ice, multiplier: 4)])
    }

    @Test func immunityCancelsWeakness() {
        let weak = TypeDamageRelations(doubleDamageFrom: [.ground], halfDamageFrom: [], noDamageFrom: [])
        let immune = TypeDamageRelations(doubleDamageFrom: [], halfDamageFrom: [], noDamageFrom: [.ground])
        #expect(WeaknessCalculator.weaknesses(from: [weak, immune]).isEmpty)
    }

    @Test func useCaseFetchesEachType() async throws {
        let client = MockHTTPClient()
        client.stub("type/grass", json: Fixtures.grassType)
        client.stub("type/poison", json: Fixtures.poisonType)
        let useCase = DefaultCalculateWeaknessesUseCase(service: PokeAPIService(client: client))
        let weaknesses = try await useCase.execute(for: [.grass, .poison])
        #expect(weaknesses.count == 4)
        #expect(client.requestedPaths.count == 2)
    }
}
