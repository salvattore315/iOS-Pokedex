import SwiftUI
import SwiftData
import Networking

@main
struct PokedexApp: App {
    private let dependencies: AppDependencies
    @State private var isSplashVisible = !ProcessInfo.processInfo.arguments.contains(SplashVideoView.skipLaunchArgument)

    init() {
        // AsyncImage and the API client cache responses on disk through the shared URL cache.
        // The default size is too small for the grid.
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
        #if DEBUG
        dependencies = UITestLaunch.dependencies() ?? .live()
        #else
        dependencies = .live()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView(dependencies: dependencies)
                if isSplashVisible {
                    SplashVideoView {
                        withAnimation(.easeOut(duration: 0.25)) { isSplashVisible = false }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

/// Everything the screens need, built once at launch and passed down through initializers.
struct AppDependencies {
    let service: any PokemonService
    let listSource: any PokemonListSource
    let favorites: any FavoritesRepository
    /// Shared so resolved regions are reused by every detail screen.
    let groupLocations: any GroupLocationsByRegionUseCase

    static func live(mode: ListSourceMode = .current) -> AppDependencies {
        // A few requests at a time, so the detail screen never queues behind dozens of list cards.
        // Own session on the disk cache sized in init(); stalled requests are retried once on a new connection.
        let client = URLSessionHTTPClient(
            session: URLSessionHTTPClient.makeSession(urlCache: .shared),
            cache: ResponseCache(),
            limiter: RequestLimiter(maxConcurrent: 4)
        )
        return make(client: client, mode: mode, isStoredInMemoryOnly: false)
    }

    /// Builds the whole graph on top of `client`.
    /// - Parameter isStoredInMemoryOnly: `true` starts with an empty index and no favorites on every launch.
    static func make(client: any HTTPClient, mode: ListSourceMode, isStoredInMemoryOnly: Bool) -> AppDependencies {
        let service = PokeAPIService(client: client)
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: PokemonIndexEntry.self, FavoritePokemon.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
            )
        } catch {
            // Without a store the app cannot keep its index; there is nothing sensible to fall back to.
            fatalError("Could not create the SwiftData container: \(error)")
        }
        let store = PokemonIndexStore(modelContainer: container)
        let local = LocalListSource(service: service, store: store)
        let listSource: any PokemonListSource = switch mode {
        case .local: local
        case .remote: RemoteListSource(service: service, local: local)
        }
        return AppDependencies(
            service: service,
            listSource: listSource,
            favorites: FavoritesStore(modelContainer: container),
            groupLocations: DefaultGroupLocationsByRegionUseCase(service: service)
        )
    }
}
