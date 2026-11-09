import SwiftUI
import DesignSystem

/// The Pokédex grid with search, region tabs and type filters.
struct PokemonListView: View {
    @State private var viewModel: PokemonListViewModel
    /// Called on a long press on the title. Only wired in DEBUG builds.
    private let onTitleLongPress: (() -> Void)?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)]

    init(viewModel: PokemonListViewModel, onTitleLongPress: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onTitleLongPress = onTitleLongPress
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            DeviceTopBar(String(localized: "list.title", defaultValue: "Pokédex"))
                .onLongPressGesture { onTitleLongPress?() }
            SearchField(
                text: $viewModel.query,
                prompt: String(localized: "list.search.prompt", defaultValue: "Search by name or number")
            )
            .padding(.horizontal, Spacing.lg)
            regionTabs
            typeFilter
            content
        }
        .background(Color.DS.surface)
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .task(id: viewModel.query) {
            // Debounce: a new keystroke cancels this task before the sleep ends.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await viewModel.applyFilters()
        }
    }

    // MARK: - Filters

    private var regionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                RegionTab(
                    String(localized: "list.region.all", defaultValue: "All"),
                    isSelected: viewModel.selectedGeneration == nil
                ) {
                    Task { await viewModel.select(generation: nil) }
                }
                ForEach(Generation.allCases) { generation in
                    RegionTab(generation.regionName, isSelected: viewModel.selectedGeneration == generation) {
                        Task { await viewModel.select(generation: generation) }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private var typeFilter: some View {
        FilterBar(
            allLabel: String(localized: "list.type.all", defaultValue: "All types"),
            options: PokemonType.allCases.map { .init(id: $0, label: $0.displayName, tint: $0.tint.color) },
            selection: Binding(
                get: { viewModel.selectedType },
                set: { type in Task { await viewModel.select(type: type) } }
            )
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            grid {
                ForEach(0..<8, id: \.self) { _ in SkeletonCard() }
            }
            .allowsHitTesting(false)
        case .loaded(let items):
            grid {
                ForEach(items) { item in
                    NavigationLink(value: item.id) {
                        card(for: item)
                    }
                    .buttonStyle(.plain)
                    .task { await viewModel.loadTypes(for: item.id) }
                    .onAppear { Task { await viewModel.loadMoreIfNeeded(after: item) } }
                }
            } footer: {
                if viewModel.isLoadingMore {
                    ProgressView().padding(Spacing.lg)
                }
            }
        case .empty:
            message(StateMessage(
                systemImage: "magnifyingglass",
                title: String(localized: "list.empty.title", defaultValue: "No results"),
                message: String(localized: "list.empty.message", defaultValue: "Try another name, number or filter.")
            ))
        case .failed(let error):
            message(StateMessage(
                systemImage: "wifi.exclamationmark",
                title: error.title,
                message: error.message,
                actionTitle: error.isRetryable ? String(localized: "action.retry", defaultValue: "Retry") : nil,
                action: error.isRetryable ? { Task { await viewModel.retry() } } : nil
            ))
        }
    }

    private func grid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        grid(content) { EmptyView() }
    }

    private func grid<Content: View, Footer: View>(
        @ViewBuilder _ content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                content()
            }
            .padding(.horizontal, Spacing.lg)
            footer()
                .padding(.bottom, Spacing.xl)
        }
    }

    private func message(_ message: StateMessage) -> some View {
        message
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card(for item: PokemonSummary) -> some View {
        PokemonCard(
            name: item.name,
            number: item.id,
            types: (viewModel.types[item.id] ?? []).map(\.badge)
        ) {
            AsyncImage(url: item.artworkURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Color.clear
                }
            }
        }
    }
}

extension PokemonSummary {
    /// Official artwork, built from the ID so the list needs no extra request per card.
    /// `AsyncImage` caches it through `URLCache.shared`, sized in `PokedexApp`.
    var artworkURL: URL? {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(id).png")
    }
}
