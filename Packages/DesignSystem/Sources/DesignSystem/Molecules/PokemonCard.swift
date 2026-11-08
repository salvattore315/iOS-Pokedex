import SwiftUI

/// Grid card: artwork on a tinted tile, name, number and type chips.
/// The top stripe and the tile use the color of the first type.
///
/// The artwork is a slot so the app decides how to load the image (for example a cached image view).
public struct PokemonCard<Artwork: View>: View {
    private let name: String
    private let number: Int
    private let types: [TypeBadge]
    private let artwork: Artwork

    public init(name: String, number: Int, types: [TypeBadge], @ViewBuilder artwork: () -> Artwork) {
        self.name = name
        self.number = number
        self.types = types
        self.artwork = artwork()
    }

    private var tint: Color { types.first?.tint.color ?? Color.DS.textSecondary }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            artwork
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(tint.opacity(0.22), in: .rect(cornerRadius: 6))
            HStack {
                Text(name.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.DS.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.xs)
                Text(Self.formatted(number))
                    .font(.mono(11))
                    .foregroundStyle(Color.DS.textSecondary)
            }
            HStack(spacing: Spacing.xs) {
                ForEach(types, id: \.self) { TypeChip($0.label, tint: $0.tint) }
            }
        }
        .padding(Spacing.sm)
        .background(Color.DS.surface)
        .overlay(alignment: .top) { tint.frame(height: 4) }
        .clipShape(.rect(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
    }

    /// Formats a number as "#001".
    nonisolated public static func formatted(_ number: Int) -> String {
        "#" + String(format: "%03d", number)
    }
}

#Preview {
    HStack {
        PokemonCard(name: "bulbasaur", number: 1, types: [.init(label: "Grass", tint: .grass), .init(label: "Poison", tint: .poison)]) {
            Circle().fill(TypeTint.grass.color.opacity(0.6)).frame(width: 80)
        }
        PokemonCard(name: "charmander", number: 4, types: [.init(label: "Fire", tint: .fire)]) {
            Circle().fill(TypeTint.fire.color.opacity(0.6)).frame(width: 80)
        }
    }
    .padding()
    .background(Color.DS.viewer)
}
