import SwiftUI

/// One place where the Pokémon can be found.
public struct LocationRow: View {
    private let title: String
    private let subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill").foregroundStyle(Color.DS.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13)).foregroundStyle(Color.DS.textPrimary)
                Text(subtitle.uppercased()).font(.mono(9)).foregroundStyle(Color.DS.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .background(Color.DS.module)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LocationRow(title: "Viridian Forest", subtitle: "Red · Walk").padding()
}
