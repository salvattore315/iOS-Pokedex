import Foundation
import Observation

/// Loads everything the detail screen shows. The Pokémon itself is required; every other
/// section loads in parallel and fails on its own, so one broken request never hides the rest.
@MainActor
@Observable
final class PokemonDetailViewModel {
    let id: Int

    private(set) var pokemon: ViewState<Pokemon> = .idle
    private(set) var species: ViewState<PokemonSpecies> = .idle
    /// Every stage of the evolution chain, in order.
    private(set) var evolutions: ViewState<[EvolutionNode]> = .idle
    private(set) var weaknesses: ViewState<[Weakness]> = .idle
    /// Where the Pokémon can be found, grouped by region.
    private(set) var locations: ViewState<[RegionLocations]> = .idle

    private let service: any PokemonService
    private let calculateWeaknesses: any CalculateWeaknessesUseCase
    private let groupLocations: any GroupLocationsByRegionUseCase

    init(
        id: Int,
        service: any PokemonService,
        calculateWeaknesses: any CalculateWeaknessesUseCase,
        groupLocations: any GroupLocationsByRegionUseCase
    ) {
        self.id = id
        self.service = service
        self.calculateWeaknesses = calculateWeaknesses
        self.groupLocations = groupLocations
    }

    func load() async {
        pokemon = .loading
        let loaded: Pokemon
        do throws(AppError) {
            loaded = try await service.pokemon(id: id)
        } catch {
            pokemon = .failed(error)
            return
        }
        pokemon = .loaded(loaded)

        async let speciesAndEvolutions: Void = loadSpecies(id: loaded.speciesID)
        async let typeWeaknesses: Void = loadWeaknesses(for: loaded.types)
        async let placesFound: Void = loadLocations()
        _ = await (speciesAndEvolutions, typeWeaknesses, placesFound)
    }

    // MARK: - Retry

    /// Loads species and evolutions again. Does nothing until the Pokémon itself has loaded.
    func retryEvolutions() async {
        guard let pokemon = pokemon.value else { return }
        await loadSpecies(id: pokemon.speciesID)
    }

    /// Loads the weaknesses again. Does nothing until the Pokémon itself has loaded.
    func retryWeaknesses() async {
        guard let pokemon = pokemon.value else { return }
        await loadWeaknesses(for: pokemon.types)
    }

    /// Loads the locations again. Does nothing until the Pokémon itself has loaded.
    func retryLocations() async {
        guard pokemon.value != nil else { return }
        await loadLocations()
    }

    // MARK: - Sections

    private func loadSpecies(id speciesID: Int) async {
        species = .loading
        evolutions = .loading
        do throws(AppError) {
            let loaded = try await service.species(id: speciesID)
            species = .loaded(loaded)
            guard let url = loaded.evolutionChainURL else {
                evolutions = .empty
                return
            }
            let chain = try await service.evolutionChain(url: url)
            let stages = chain.stages
            // A chain with a single stage means the Pokémon does not evolve.
            evolutions = stages.count > 1 ? .loaded(stages) : .empty
        } catch {
            if case .loading = species { species = .failed(error) }
            evolutions = .failed(error)
        }
    }

    private func loadWeaknesses(for types: [PokemonType]) async {
        weaknesses = .loading
        do throws(AppError) {
            let result = try await calculateWeaknesses.execute(for: types)
            weaknesses = result.isEmpty ? .empty : .loaded(result)
        } catch {
            weaknesses = .failed(error)
        }
    }

    /// Only the encounters request can fail the section. Areas whose region cannot be
    /// resolved still show up, in a group without a region.
    private func loadLocations() async {
        locations = .loading
        do throws(AppError) {
            let encounters = try await service.encounters(pokemonID: id)
            guard !encounters.isEmpty else {
                locations = .empty
                return
            }
            locations = .loaded(await groupLocations.execute(encounters))
        } catch {
            locations = .failed(error)
        }
    }
}
