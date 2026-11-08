import SwiftUI

/// Light-blue LCD panel with the base stats.
public struct StatsLCD: View {
    /// One stat line.
    public struct Entry: Identifiable, Hashable {
        public let label: String
        public let value: Int
        public var id: String { label }

        public init(label: String, value: Int) {
            self.label = label
            self.value = value
        }
    }

    private let title: String
    private let entries: [Entry]
    private let tint: Color

    public init(title: String, entries: [Entry], tint: Color) {
        self.title = title
        self.entries = entries
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.mono(11, weight: .bold)).foregroundStyle(Color.DS.lcdText)
            ForEach(entries) { StatRow(label: $0.label, value: $0.value, tint: tint) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.DS.lcd, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.DS.segmentOff, lineWidth: 2))
    }
}

#Preview {
    StatsLCD(title: "Base stats", entries: [
        .init(label: "HP", value: 45), .init(label: "Atk", value: 49), .init(label: "Def", value: 49),
        .init(label: "Sp.A", value: 65), .init(label: "Sp.D", value: 65), .init(label: "Spd", value: 45),
    ], tint: TypeTint.grass.color)
    .padding()
}
