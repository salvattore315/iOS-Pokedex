import Foundation

// Converts PokéAPI DTOs into domain models. This is the only place that knows the API's shape.

extension PokemonListDTO {
    func toPage(offset: Int) -> Page<PokemonSummary> {
        let items = results.compactMap { $0.toSummary() }
        return Page(items: items, totalCount: count, nextOffset: next == nil ? nil : offset + results.count)
    }
}

extension NamedAPIResourceDTO {
    func toSummary() -> PokemonSummary? {
        guard let id else { return nil }
        return PokemonSummary(id: id, name: name)
    }
}

extension PokemonDTO {
    func toDomain() -> Pokemon {
        Pokemon(
            id: id,
            name: name,
            types: types.sorted { $0.slot < $1.slot }.compactMap { PokemonType(rawValue: $0.type.name) },
            heightInMeters: Double(height) / 10,
            weightInKilograms: Double(weight) / 10,
            stats: stats.compactMap { entry in
                Stat.Kind(rawValue: entry.stat.name).map { Stat(kind: $0, value: entry.baseStat) }
            },
            artworkURL: sprites.other?.officialArtwork?.frontDefault,
            cryURL: cries?.latest ?? cries?.legacy,
            speciesID: species.id ?? id
        )
    }
}

extension PokemonSpeciesDTO {
    /// - Parameter languageCode: Preferred language, for example "es". Falls back to English.
    func toDomain(languageCode: String) -> PokemonSpecies {
        let flavor = Self.pick(flavorTextEntries, languageCode: languageCode, language: \.language.name)?.flavorText
        let genus = Self.pick(genera, languageCode: languageCode, language: \.language.name)?.genus
        return PokemonSpecies(
            id: id,
            flavorText: flavor.map(Self.clean),
            genus: genus,
            evolutionChainURL: evolutionChain?.url
        )
    }

    /// Returns the entry in `languageCode`, or in English, or `nil`.
    private static func pick<T>(_ entries: [T], languageCode: String, language: KeyPath<T, String>) -> T? {
        entries.first { $0[keyPath: language] == languageCode }
            ?? entries.first { $0[keyPath: language] == "en" }
    }

    /// Flavor texts come with hard line breaks and form feeds from the original games.
    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{0C}", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}

extension EvolutionChainDTO {
    func toDomain() -> EvolutionNode? {
        chain.toNode()
    }
}

private extension EvolutionChainDTO.Link {
    func toNode() -> EvolutionNode? {
        guard let id = species.id else { return nil }
        return EvolutionNode(
            speciesID: id,
            name: species.name,
            minLevel: evolutionDetails.compactMap(\.minLevel).first,
            evolvesTo: evolvesTo.compactMap { $0.toNode() }
        )
    }
}

extension EncounterDTO {
    func toDomain() -> Encounter {
        Encounter(
            locationArea: locationArea.name,
            versions: versionDetails.map(\.version.name),
            methods: Array(Set(versionDetails.flatMap { $0.encounterDetails.map(\.method.name) })).sorted()
        )
    }
}

extension TypeDTO {
    func toDamageRelations() -> TypeDamageRelations {
        TypeDamageRelations(
            doubleDamageFrom: Self.types(damageRelations.doubleDamageFrom),
            halfDamageFrom: Self.types(damageRelations.halfDamageFrom),
            noDamageFrom: Self.types(damageRelations.noDamageFrom)
        )
    }

    var pokemonIDs: Set<Int> {
        Set(pokemon.compactMap(\.pokemon.id))
    }

    private static func types(_ resources: [NamedAPIResourceDTO]) -> Set<PokemonType> {
        Set(resources.compactMap { PokemonType(rawValue: $0.name) })
    }
}

extension GenerationDTO {
    var speciesIDs: Set<Int> {
        Set(pokemonSpecies.compactMap(\.id))
    }
}
