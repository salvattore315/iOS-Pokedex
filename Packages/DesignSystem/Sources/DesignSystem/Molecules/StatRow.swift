import SwiftUI

/// One stat of the LCD: short name, value and a 10-segment meter that fills with animation.
public struct StatRow: View {
    /// Number of segments in the meter.
    nonisolated public static let segmentCount = 10
    /// Value that fills the whole meter. Base stats go up to 255.
    nonisolated public static let maxValue = 255

    private let label: String
    private let value: Int
    private let tint: Color
    @State private var isFilled = false

    public init(label: String, value: Int, tint: Color) {
        self.label = label
        self.value = value
        self.tint = tint
    }

    /// How many segments are lit for `value`. At least one for any positive value.
    nonisolated public static func litSegments(for value: Int) -> Int {
        guard value > 0 else { return 0 }
        let ratio = Double(min(value, maxValue)) / Double(maxValue)
        return max(1, Int((ratio * Double(segmentCount)).rounded()))
    }

    public var body: some View {
        let lit = Self.litSegments(for: value)
        HStack(spacing: Spacing.sm) {
            Text(label.uppercased())
                .font(.mono(11, weight: .bold))
                .frame(width: 40, alignment: .leading)
            Text("\(value)")
                .font(.mono(11))
                .frame(width: 28, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(0..<Self.segmentCount, id: \.self) { index in
                    StatSegment(isOn: isFilled && index < lit, tint: tint)
                        .animation(.easeOut(duration: 0.25).delay(Double(index) * 0.04), value: isFilled)
                }
            }
        }
        .foregroundStyle(Color.DS.lcdText)
        .onAppear { isFilled = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

#Preview {
    VStack(alignment: .leading) {
        StatRow(label: "HP", value: 45, tint: TypeTint.grass.color)
        StatRow(label: "Sp. Atk", value: 65, tint: TypeTint.grass.color)
    }
    .padding()
    .background(Color.DS.lcd)
}
