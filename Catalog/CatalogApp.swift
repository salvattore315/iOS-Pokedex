import DesignSystem
import SwiftUI

/// Standalone app that only shows the design system catalog.
@main
struct CatalogApp: App {
    var body: some Scene {
        WindowGroup {
            DesignSystemCatalog()
        }
    }
}
