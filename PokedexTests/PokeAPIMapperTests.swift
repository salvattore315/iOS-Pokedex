import Foundation
import Testing
@testable import Pokedex

/// Decodes a JSON fixture the same way `URLSessionHTTPClient` does.
func decodeFixture<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(T.self, from: Data(json.utf8))
}

enum Fixtures {
    static let bulbasaur = """
    {
      "id": 1, "name": "bulbasaur", "height": 7, "weight": 69,
      "types": [
        {"slot": 2, "type": {"name": "poison", "url": "https://pokeapi.co/api/v2/type/4/"}},
        {"slot": 1, "type": {"name": "grass", "url": "https://pokeapi.co/api/v2/type/12/"}}
      ],
      "stats": [
        {"base_stat": 45, "stat": {"name": "hp", "url": "https://pokeapi.co/api/v2/stat/1/"}},
        {"base_stat": 65, "stat": {"name": "special-attack", "url": "https://pokeapi.co/api/v2/stat/4/"}}
      ],
      "sprites": {"other": {"official-artwork": {"front_default": "https://example.com/1.png"}}},
      "cries": {"latest": "https://example.com/1.ogg", "legacy": null},
      "species": {"name": "bulbasaur", "url": "https://pokeapi.co/api/v2/pokemon-species/1/"}
    }
    """

    static let bulbasaurSpecies = """
    {
      "id": 1,
      "flavor_text_entries": [
        {"flavor_text": "A strange seed was\\nplanted on its\\fback at birth.", "language": {"name": "en", "url": "https://pokeapi.co/api/v2/language/9/"}},
        {"flavor_text": "Una rara semilla\\nfue plantada en su lomo.", "language": {"name": "es", "url": "https://pokeapi.co/api/v2/language/7/"}}
      ],
      "genera": [{"genus": "Seed Pokémon", "language": {"name": "en", "url": "https://pokeapi.co/api/v2/language/9/"}}],
      "evolution_chain": {"url": "https://pokeapi.co/api/v2/evolution-chain/1/"}
    }
    """

    static let bulbasaurChain = """
    {"chain": {
      "species": {"name": "bulbasaur", "url": "https://pokeapi.co/api/v2/pokemon-species/1/"},
      "evolution_details": [],
      "evolves_to": [{
        "species": {"name": "ivysaur", "url": "https://pokeapi.co/api/v2/pokemon-species/2/"},
        "evolution_details": [{"min_level": 16}],
        "evolves_to": [{
          "species": {"name": "venusaur", "url": "https://pokeapi.co/api/v2/pokemon-species/3/"},
          "evolution_details": [{"min_level": 32}],
          "evolves_to": []
        }]
      }]
    }}
    """

    static let page = """
    {"count": 1351, "next": "https://pokeapi.co/api/v2/pokemon?offset=20&limit=20", "results": [
      {"name": "bulbasaur", "url": "https://pokeapi.co/api/v2/pokemon/1/"},
      {"name": "ivysaur", "url": "https://pokeapi.co/api/v2/pokemon/2/"}
    ]}
    """

    static let grassType = """
    {"damage_relations": {
      "double_damage_from": [{"name": "fire", "url": "https://pokeapi.co/api/v2/type/10/"}, {"name": "ice", "url": "https://pokeapi.co/api/v2/type/15/"}, {"name": "flying", "url": "https://pokeapi.co/api/v2/type/3/"}, {"name": "poison", "url": "https://pokeapi.co/api/v2/type/4/"}, {"name": "bug", "url": "https://pokeapi.co/api/v2/type/7/"}],
      "half_damage_from": [{"name": "water", "url": "https://pokeapi.co/api/v2/type/11/"}, {"name": "grass", "url": "https://pokeapi.co/api/v2/type/12/"}, {"name": "electric", "url": "https://pokeapi.co/api/v2/type/13/"}, {"name": "ground", "url": "https://pokeapi.co/api/v2/type/5/"}],
      "no_damage_from": []
    }, "pokemon": [{"pokemon": {"name": "bulbasaur", "url": "https://pokeapi.co/api/v2/pokemon/1/"}}]}
    """

    static let poisonType = """
    {"damage_relations": {
      "double_damage_from": [{"name": "ground", "url": "https://pokeapi.co/api/v2/type/5/"}, {"name": "psychic", "url": "https://pokeapi.co/api/v2/type/14/"}],
      "half_damage_from": [{"name": "fighting", "url": "https://pokeapi.co/api/v2/type/2/"}, {"name": "poison", "url": "https://pokeapi.co/api/v2/type/4/"}, {"name": "bug", "url": "https://pokeapi.co/api/v2/type/7/"}, {"name": "grass", "url": "https://pokeapi.co/api/v2/type/12/"}, {"name": "fairy", "url": "https://pokeapi.co/api/v2/type/18/"}],
      "no_damage_from": []
    }, "pokemon": [{"pokemon": {"name": "bulbasaur", "url": "https://pokeapi.co/api/v2/pokemon/1/"}}]}
    """
}

struct PokeAPIMapperTests {
    @Test func mapsPokemon() throws {
        let pokemon = try decodeFixture(PokemonDTO.self, Fixtures.bulbasaur).toDomain()
        #expect(pokemon.id == 1)
        #expect(pokemon.types == [.grass, .poison])
        #expect(pokemon.heightInMeters == 0.7)
        #expect(pokemon.weightInKilograms == 6.9)
        #expect(pokemon.stats == [Stat(kind: .hp, value: 45), Stat(kind: .specialAttack, value: 65)])
        #expect(pokemon.artworkURL?.absoluteString == "https://example.com/1.png")
        #expect(pokemon.cryURL?.absoluteString == "https://example.com/1.ogg")
        #expect(pokemon.speciesID == 1)
    }

    @Test func picksSpeciesTextInUserLanguageAndCleansIt() throws {
        let dto = try decodeFixture(PokemonSpeciesDTO.self, Fixtures.bulbasaurSpecies)
        #expect(dto.toDomain(languageCode: "es").flavorText == "Una rara semilla fue plantada en su lomo.")
        #expect(dto.toDomain(languageCode: "en").flavorText == "A strange seed was planted on its back at birth.")
    }

    @Test func fallsBackToEnglish() throws {
        let species = try decodeFixture(PokemonSpeciesDTO.self, Fixtures.bulbasaurSpecies).toDomain(languageCode: "fr")
        #expect(species.genus == "Seed Pokémon")
        #expect(species.evolutionChainURL?.absoluteString == "https://pokeapi.co/api/v2/evolution-chain/1/")
    }

    @Test func mapsEvolutionChain() throws {
        let chain = try #require(try decodeFixture(EvolutionChainDTO.self, Fixtures.bulbasaurChain).toDomain())
        #expect(chain.stages.map(\.name) == ["bulbasaur", "ivysaur", "venusaur"])
        #expect(chain.stages.map(\.minLevel) == [nil, 16, 32])
    }

    @Test func mapsPageAndNextOffset() throws {
        let page = try decodeFixture(PokemonListDTO.self, Fixtures.page).toPage(offset: 0)
        #expect(page.items == [PokemonSummary(id: 1, name: "bulbasaur"), PokemonSummary(id: 2, name: "ivysaur")])
        #expect(page.totalCount == 1351)
        #expect(page.nextOffset == 2)
    }

    @Test func mapsTypeRelations() throws {
        let type = try decodeFixture(TypeDTO.self, Fixtures.grassType)
        #expect(type.toDamageRelations().doubleDamageFrom == [.fire, .ice, .flying, .poison, .bug])
        #expect(type.pokemonIDs == [1])
    }
}
