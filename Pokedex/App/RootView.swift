import SwiftUI
import DesignSystem

/// The tab bar. Each tab owns its navigation stack.
struct RootView: View {
    @State private var listViewModel: PokemonListViewModel
    @State private var isCatalogPresented = false
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _listViewModel = State(initialValue: PokemonListViewModel(source: dependencies.listSource, service: dependencies.service))
    }

    var body: some View {
        TabView {
            NavigationStack {
                PokemonListView(viewModel: listViewModel, onTitleLongPress: openCatalog)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Int.self) { id in
                        // Also handles taps on evolutions, which push the same destination.
                        PokemonDetailView(viewModel: PokemonDetailViewModel(
                            id: id,
                            service: dependencies.service,
                            calculateWeaknesses: DefaultCalculateWeaknessesUseCase(service: dependencies.service)
                        ))
                    }
            }
            .tabItem {
                Label(String(localized: "tab.pokedex", defaultValue: "Pokédex"), systemImage: "square.grid.2x2")
            }

            FavoritesPlaceholderView()
                .tabItem {
                    Label(String(localized: "tab.favorites", defaultValue: "Favorites"), systemImage: "heart")
                }
        }
        .sheet(isPresented: $isCatalogPresented) {
            DesignSystemCatalog()
        }
    }

    /// The design-system catalog is a developer tool: release builds ignore the long press.
    private var openCatalog: (() -> Void)? {
        #if DEBUG
        { isCatalogPresented = true }
        #else
        nil
        #endif
    }
}
