import SwiftUI
import SwiftData
import Networking

@main
struct PokedexApp: App {
    private let dependencies: AppDependencies

    init() {
        // AsyncImage caches artwork through the shared URL cache. The default size is too small for the grid.
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
        dependencies = .live()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}

/// Everything the screens need, built once at launch and passed down through initializers.
struct AppDependencies {
    let service: any PokemonService
    let listSource: any PokemonListSource

    static func live(mode: ListSourceMode = .current) -> AppDependencies {
        let client = URLSessionHTTPClient(cache: ResponseCache())
        let service = PokeAPIService(client: client)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: PokemonIndexEntry.self)
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
        return AppDependencies(service: service, listSource: listSource)
    }
}
