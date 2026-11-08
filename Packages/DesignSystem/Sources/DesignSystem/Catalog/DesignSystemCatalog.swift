import SwiftUI

/// Browsable list of every token and component, grouped like the Figma "Design System" page.
/// Shown by the PokedexCatalog app and, in debug builds, from inside the main app.
public struct DesignSystemCatalog: View {
    @State private var colorScheme: ColorScheme = .light

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Tokens") {
                    page("Colors") { ColorsPage() }
                    page("Type colors") { FlowPreview(items: TypeTint.allCases) { TypeChip($0.rawValue, tint: $0) } }
                    page("Typography") { TypographyPage() }
                }
                Section("Atoms") {
                    page("TypeChip") { FlowPreview(items: TypeTint.allCases) { TypeChip($0.rawValue, tint: $0) } }
                    page("FilterChip") { FilterChipPage() }
                    page("StatSegment") { HStack(spacing: 3) { StatSegment(isOn: true, tint: TypeTint.fire.color); StatSegment(isOn: false, tint: TypeTint.fire.color) } }
                    page("RegionTab") { HStack { RegionTab("Kanto", isSelected: true) {}; RegionTab("Johto", isSelected: false) {} } }
                    page("SectionTitle") { SectionTitle("About") }
                    page("IconButton") { HStack { IconButton(systemName: "chevron.left", accessibilityLabel: "Back") {}; IconButton(systemName: "heart.fill", accessibilityLabel: "Favorite", tint: Color.DS.accent) {} } }
                    page("AccentButtonStyle") { Button("Retry") {}.buttonStyle(.accent) }
                }
                Section("Molecules") {
                    page("PokemonCard") { CardsPage() }
                    page("SearchField") { SearchFieldPage() }
                    page("Readout") { HStack { Readout(label: "Height", value: "0.7 m"); Readout(label: "Weight", value: "6.9 kg") } }
                    page("StatRow") { StatRow(label: "HP", value: 45, tint: TypeTint.grass.color).padding().background(Color.DS.lcd) }
                    page("EvolutionNodeView") { HStack { EvolutionNodeView(name: "bulbasaur", level: nil, isCurrent: true, tint: TypeTint.grass.color) { EmptyView() }; EvolutionNodeView(name: "ivysaur", level: 16, isCurrent: false, tint: TypeTint.grass.color) { EmptyView() } } }
                    page("LocationRow") { LocationRow(title: "Viridian Forest", subtitle: "Red · Walk") }
                }
                Section("Organisms") {
                    page("DeviceTopBar") { DeviceTopBar("Pokédex").background(Color.DS.shell) }
                    page("DetailTopBar") { DetailTopBar(isFavorite: true, onBack: {}, onCry: {}, onFavorite: {}).background(Color.DS.shell) }
                    page("ScanViewer") { ScanViewer(number: 1, tint: TypeTint.grass.color) { Circle().fill(TypeTint.grass.color.opacity(0.6)) } }
                    page("StatsLCD") { StatsLCD(title: "Base stats", entries: [.init(label: "HP", value: 45), .init(label: "Atk", value: 49), .init(label: "Spd", value: 45)], tint: TypeTint.grass.color) }
                    page("StateMessage") { StateMessage(systemImage: "wifi.slash", title: "No connection", message: "Check your connection and try again.", actionTitle: "Retry") {} }
                    page("SkeletonCard") { SkeletonCard().frame(width: 170) }
                }
            }
            .navigationTitle("Design System")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Appearance", selection: $colorScheme) {
                        Image(systemName: "sun.max").tag(ColorScheme.light)
                        Image(systemName: "moon").tag(ColorScheme.dark)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .preferredColorScheme(colorScheme)
    }

    private func page<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        NavigationLink(title) {
            ScrollView {
                content().padding()
            }
            .frame(maxWidth: .infinity)
            .background(Color.DS.viewer)
            .navigationTitle(title)
        }
    }
}

private struct ColorsPage: View {
    private let tokens: [(String, Color)] = [
        ("shell", Color.DS.shell), ("viewer", Color.DS.viewer), ("surface", Color.DS.surface), ("surfaceMuted", Color.DS.surfaceMuted),
        ("module", Color.DS.module), ("panel", Color.DS.panel), ("lcd", Color.DS.lcd), ("lcdText", Color.DS.lcdText),
        ("segmentOff", Color.DS.segmentOff), ("border", Color.DS.border), ("accent", Color.DS.accent), ("accentText", Color.DS.accentText),
        ("onAccent", Color.DS.onAccent), ("textPrimary", Color.DS.textPrimary), ("textSecondary", Color.DS.textSecondary),
        ("onShell", Color.DS.onShell), ("danger", Color.DS.danger),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: Spacing.md) {
            ForEach(tokens, id: \.0) { name, color in
                VStack(spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: Radius.md).fill(color).frame(height: 56)
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.DS.border))
                    Text(name).font(.mono(10)).foregroundStyle(Color.DS.textPrimary)
                }
            }
        }
    }
}

private struct TypographyPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("POKÉDEX").font(.mono(26, weight: .bold))
            Text("BASE STATS").font(.mono(11, weight: .bold))
            Text("#001 · 0.7 m · 6.9 kg").font(.mono(12))
            Text("Bulbasaur").font(.system(size: 24, weight: .bold))
        }
        .foregroundStyle(Color.DS.textPrimary)
    }
}

private struct FilterChipPage: View {
    @State private var selection: TypeTint?

    var body: some View {
        FilterBar(allLabel: "All", options: TypeTint.allCases.map { .init(id: $0, label: $0.rawValue, tint: $0.color) }, selection: $selection)
    }
}

private struct SearchFieldPage: View {
    @State private var text = ""

    var body: some View {
        SearchField(text: $text, prompt: "Search name or number").padding().background(Color.DS.shell)
    }
}

private struct CardsPage: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(), GridItem()], spacing: Spacing.sm) {
            PokemonCard(name: "bulbasaur", number: 1, types: [.init(label: "Grass", tint: .grass), .init(label: "Poison", tint: .poison)]) {
                Circle().fill(TypeTint.grass.color.opacity(0.6)).frame(width: 80)
            }
            PokemonCard(name: "pikachu", number: 25, types: [.init(label: "Electric", tint: .electric)]) {
                Circle().fill(TypeTint.electric.color.opacity(0.6)).frame(width: 80)
            }
        }
    }
}

#Preview {
    DesignSystemCatalog()
}
