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
    private(set) var encounters: ViewState<[Encounter]> = .idle
    private(set) var isFavorite = false

    private let service: any PokemonService
    private let calculateWeaknesses: any CalculateWeaknessesUseCase
    private let favorites: any FavoritesRepository
    private let now: @Sendable () -> Date

    /// - Parameter now: Date stamped on new favorites. Inject a fixed one in tests.
    init(
        id: Int,
        service: any PokemonService,
        calculateWeaknesses: any CalculateWeaknessesUseCase,
        favorites: any FavoritesRepository,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.id = id
        self.service = service
        self.calculateWeaknesses = calculateWeaknesses
        self.favorites = favorites
        self.now = now
    }

    func load() async {
        // Read from the local store, so the button is right even if the Pokémon fails to load.
        isFavorite = (try? await favorites.isFavorite(id: id)) ?? false
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
        async let locations: Void = loadEncounters()
        _ = await (speciesAndEvolutions, typeWeaknesses, locations)
    }

    // MARK: - Favorite

    /// Adds the Pokémon to favorites or removes it. Needs the Pokémon to be loaded.
    /// If the store fails, the button keeps showing the stored state.
    func toggleFavorite() async {
        guard let loaded = pokemon.value else { return }
        let shouldAdd = !isFavorite
        do {
            if shouldAdd {
                try await favorites.add(Favorite(loaded, addedAt: now()))
            } else {
                try await favorites.remove(id: loaded.id)
            }
            isFavorite = shouldAdd
        } catch {
            isFavorite = (try? await favorites.isFavorite(id: loaded.id)) ?? isFavorite
        }
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
    func retryEncounters() async {
        guard pokemon.value != nil else { return }
        await loadEncounters()
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

    private func loadEncounters() async {
        encounters = .loading
        do throws(AppError) {
            let result = try await service.encounters(pokemonID: id)
            encounters = result.isEmpty ? .empty : .loaded(result)
        } catch {
            encounters = .failed(error)
        }
    }
}
