import SwiftUI

@main
struct PokedexApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Text("Pokédex")
                .tabItem { Label("Pokédex", systemImage: "square.grid.2x2") }
            Text("Favorites")
                .tabItem { Label("Favorites", systemImage: "heart") }
        }
    }
}

#Preview {
    RootView()
}
