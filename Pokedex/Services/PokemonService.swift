import Foundation

/// The data the features need, independent of where it comes from.
/// `PokeAPIService` implements it over REST; a GraphQL implementation can come later.
protocol PokemonService: Sendable {
    /// Every Pokémon name and ID, for local search. One request.
    func pokemonIndex() async throws(AppError) -> [PokemonSummary]
    func pokemonPage(offset: Int, limit: Int) async throws(AppError) -> Page<PokemonSummary>
    func pokemon(id: Int) async throws(AppError) -> Pokemon
    func species(id: Int) async throws(AppError) -> PokemonSpecies
    func evolutionChain(url: URL) async throws(AppError) -> EvolutionNode
    func encounters(pokemonID: Int) async throws(AppError) -> [Encounter]
    func damageRelations(for type: PokemonType) async throws(AppError) -> TypeDamageRelations
    func pokemonIDs(ofType type: PokemonType) async throws(AppError) -> Set<Int>
    func speciesIDs(inGeneration id: Int) async throws(AppError) -> Set<Int>
}
