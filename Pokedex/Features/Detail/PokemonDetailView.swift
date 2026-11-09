import SwiftUI
import DesignSystem

/// The detail screen. Each section shows its own loading, empty or error state.
struct PokemonDetailView: View {
    @State private var viewModel: PokemonDetailViewModel
    @State private var cryPlayer = CryPlayer()
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PokemonDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(
                isFavorite: false,
                isCryAvailable: cryURL != nil,
                onBack: { dismiss() },
                onCry: { if let cryURL { cryPlayer.play(cryURL) } },
                // Wired in the Favorites epic.
                onFavorite: {}
            )
            content
        }
        .background(Color.DS.surface)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .idle = viewModel.pokemon { await viewModel.load() }
        }
    }

    /// `nil` hides the cry button: no URL, or an iOS version that cannot play Ogg.
    private var cryURL: URL? {
        guard CryPlayer.isSupported else { return nil }
        return viewModel.pokemon.value?.cryURL
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.pokemon {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let pokemon):
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header(pokemon)
                    about(pokemon)
                    stats(pokemon)
                    weaknesses
                    evolutions(current: pokemon)
                    locations
                }
                .padding(Spacing.lg)
            }
        case .empty:
            EmptyView()
        case .failed(let error):
            StateMessage(
                systemImage: "exclamationmark.triangle",
                title: error.title,
                message: error.message,
                actionTitle: error.isRetryable ? String(localized: "action.retry", defaultValue: "Retry") : nil,
                action: error.isRetryable ? { Task { await viewModel.load() } } : nil
            )
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Sections

    private func header(_ pokemon: Pokemon) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ScanViewer(number: pokemon.id, tint: tint(of: pokemon)) {
                artwork(pokemon.artworkURL)
            }
            Text(pokemon.name.capitalized)
                .font(.mono(24, weight: .bold))
                .foregroundStyle(Color.DS.textPrimary)
            HStack(spacing: Spacing.sm) {
                ForEach(pokemon.types, id: \.self) { type in
                    TypeChip(type.displayName, tint: type.tint)
                }
            }
        }
    }

    private func about(_ pokemon: Pokemon) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionTitle(String(localized: "detail.about", defaultValue: "About"))
            if let species = viewModel.species.value {
                if let genus = species.genus {
                    Text(genus).font(.mono(13, weight: .bold)).foregroundStyle(Color.DS.textSecondary)
                }
                if let flavorText = species.flavorText {
                    Text(flavorText).font(.body).foregroundStyle(Color.DS.textPrimary)
                }
            }
            HStack(spacing: Spacing.xl) {
                Readout(
                    label: String(localized: "detail.height", defaultValue: "Height"),
                    value: pokemon.heightInMeters.formatted(.number.precision(.fractionLength(1))) + " m"
                )
                Readout(
                    label: String(localized: "detail.weight", defaultValue: "Weight"),
                    value: pokemon.weightInKilograms.formatted(.number.precision(.fractionLength(1))) + " kg"
                )
            }
        }
    }

    private func stats(_ pokemon: Pokemon) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(String(localized: "detail.stats", defaultValue: "Base stats"))
            ForEach(pokemon.stats, id: \.kind) { stat in
                StatRow(label: stat.kind.shortLabel, value: stat.value, tint: tint(of: pokemon))
            }
        }
    }

    private var weaknesses: some View {
        section(
            String(localized: "detail.weaknesses", defaultValue: "Weaknesses"),
            state: viewModel.weaknesses,
            emptyText: String(localized: "detail.weaknesses.empty", defaultValue: "No weaknesses.")
        ) { weaknesses in
            FlowLayout(spacing: Spacing.sm) {
                ForEach(weaknesses, id: \.type) { weakness in
                    TypeChip("\(weakness.type.displayName) ×\(weakness.multiplier.formatted())", tint: weakness.type.tint)
                }
            }
        }
    }

    private func evolutions(current pokemon: Pokemon) -> some View {
        section(
            String(localized: "detail.evolutions", defaultValue: "Evolutions"),
            state: viewModel.evolutions,
            emptyText: String(localized: "detail.evolutions.empty", defaultValue: "This Pokémon does not evolve.")
        ) { stages in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(stages) { stage in
                        let isCurrent = stage.speciesID == pokemon.speciesID
                        NavigationLink(value: stage.speciesID) {
                            EvolutionNodeView(name: stage.name, level: stage.minLevel, isCurrent: isCurrent, tint: tint(of: pokemon)) {
                                artwork(PokemonSummary(id: stage.speciesID, name: stage.name).artworkURL)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isCurrent)
                    }
                }
            }
        }
    }

    private var locations: some View {
        section(
            String(localized: "detail.locations", defaultValue: "Locations"),
            state: viewModel.encounters,
            emptyText: String(localized: "detail.locations.empty", defaultValue: "Not found in the wild.")
        ) { encounters in
            VStack(spacing: Spacing.sm) {
                ForEach(encounters, id: \.locationArea) { encounter in
                    LocationRow(
                        title: encounter.locationArea.slugTitle,
                        subtitle: encounter.versions.map(\.slugTitle).joined(separator: ", ")
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    /// Title plus the right content for a section's state.
    private func section<Value, Content: View>(
        _ title: String,
        state: ViewState<Value>,
        emptyText: String,
        @ViewBuilder content: @escaping (Value) -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionTitle(title)
            switch state {
            case .idle, .loading:
                ProgressView()
            case .loaded(let value):
                content(value)
            case .empty:
                Text(emptyText).font(.callout).foregroundStyle(Color.DS.textSecondary)
            case .failed(let error):
                Text(error.message).font(.callout).foregroundStyle(Color.DS.danger)
            }
        }
    }

    private func artwork(_ url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
    }

    private func tint(of pokemon: Pokemon) -> Color {
        pokemon.types.first?.tint.color ?? Color.DS.accent
    }
}

private extension Stat.Kind {
    var shortLabel: String {
        switch self {
        case .hp: "HP"
        case .attack: String(localized: "stat.attack", defaultValue: "Atk")
        case .defense: String(localized: "stat.defense", defaultValue: "Def")
        case .specialAttack: String(localized: "stat.specialAttack", defaultValue: "SpA")
        case .specialDefense: String(localized: "stat.specialDefense", defaultValue: "SpD")
        case .speed: String(localized: "stat.speed", defaultValue: "Spe")
        }
    }
}

private extension String {
    /// "viridian-forest-area" → "Viridian Forest Area".
    var slugTitle: String {
        split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }
}
