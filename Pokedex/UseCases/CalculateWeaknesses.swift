/// A type that deals extra damage to a Pokémon, with its combined multiplier (×2 or ×4).
struct Weakness: Hashable, Sendable {
    let type: PokemonType
    let multiplier: Double
}

/// Works out a Pokémon's weaknesses from the damage relations of its types.
protocol CalculateWeaknessesUseCase: Sendable {
    func execute(for types: [PokemonType]) async throws(AppError) -> [Weakness]
}

struct DefaultCalculateWeaknessesUseCase: CalculateWeaknessesUseCase {
    let service: any PokemonService

    func execute(for types: [PokemonType]) async throws(AppError) -> [Weakness] {
        var relations: [TypeDamageRelations] = []
        for type in types {
            relations.append(try await service.damageRelations(for: type))
        }
        return WeaknessCalculator.weaknesses(from: relations)
    }
}

/// Pure calculation, kept apart from the network so it can be tested directly.
enum WeaknessCalculator {
    /// Multiplies the effect of every attacking type across all defending types
    /// and keeps those above ×1, strongest first.
    static func weaknesses(from relations: [TypeDamageRelations]) -> [Weakness] {
        PokemonType.allCases
            .map { attacker in
                Weakness(type: attacker, multiplier: relations.reduce(1) { $0 * multiplier(of: attacker, against: $1) })
            }
            .filter { $0.multiplier > 1 }
            .sorted { $0.multiplier > $1.multiplier }
    }

    private static func multiplier(of attacker: PokemonType, against relations: TypeDamageRelations) -> Double {
        if relations.noDamageFrom.contains(attacker) { return 0 }
        if relations.doubleDamageFrom.contains(attacker) { return 2 }
        if relations.halfDamageFrom.contains(attacker) { return 0.5 }
        return 1
    }
}
