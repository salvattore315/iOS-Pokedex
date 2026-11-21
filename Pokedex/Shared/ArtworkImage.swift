import SwiftUI

extension EnvironmentValues {
    /// Loads artwork for ``ArtworkImage``. `nil` (previews) leaves the placeholder in place.
    @Entry var imageLoader: ImageLoader?
}

/// A remote image loaded through ``ImageLoader``, shown scaled to fit over a clear placeholder.
///
/// The load is tied to the view: it starts when the view appears, runs with `priority`
/// and is cancelled when the view disappears or `url` changes.
struct ArtworkImage: View {
    let url: URL?
    /// Cards scrolling past use a low priority, so the artwork the user opened loads first.
    var priority: TaskPriority = .userInitiated

    @Environment(\.imageLoader) private var loader
    @State private var loaded: (url: URL, image: UIImage)?

    var body: some View {
        Group {
            if let image = displayedImage {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: url, priority: priority) { await load() }
    }

    /// The image for the current URL: the one this view loaded, or one already in memory,
    /// so a card scrolling back into view shows its artwork on the first frame.
    private var displayedImage: UIImage? {
        guard let url else { return nil }
        if let loaded, loaded.url == url { return loaded.image }
        return loader?.cachedImage(for: url)
    }

    private func load() async {
        guard let url, let loader, loaded?.url != url else { return }
        guard let image = try? await loader.image(for: url) else { return }
        loaded = (url, image)
    }
}
