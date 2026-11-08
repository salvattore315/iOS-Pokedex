import SwiftUI

/// One step of the evolution chain. The current Pokémon is outlined with its type color.
public struct EvolutionNodeView<Artwork: View>: View {
    private let name: String
    private let level: Int?
    private let isCurrent: Bool
    private let tint: Color
    private let artwork: Artwork

    public init(name: String, level: Int?, isCurrent: Bool, tint: Color, @ViewBuilder artwork: () -> Artwork) {
        self.name = name
        self.level = level
        self.isCurrent = isCurrent
        self.tint = tint
        self.artwork = artwork()
    }

    public var body: some View {
        VStack(spacing: Spacing.xs) {
            artwork
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.22), in: .rect(cornerRadius: Radius.md))
                .overlay {
                    if isCurrent { RoundedRectangle(cornerRadius: Radius.md).stroke(tint, lineWidth: 2) }
                }
            Text(name.capitalized).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.DS.textPrimary)
            Text(level.map { "LV \($0)" } ?? " ").font(.mono(9)).foregroundStyle(Color.DS.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack {
        EvolutionNodeView(name: "bulbasaur", level: 1, isCurrent: true, tint: TypeTint.grass.color) { EmptyView() }
        EvolutionNodeView(name: "ivysaur", level: 16, isCurrent: false, tint: TypeTint.grass.color) { EmptyView() }
    }
    .padding()
    .background(Color.DS.module)
}
