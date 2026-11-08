import SwiftUI

/// One block of a stat meter. Lit segments use the Pokémon's type color.
public struct StatSegment: View {
    private let isOn: Bool
    private let tint: Color

    public init(isOn: Bool, tint: Color) {
        self.isOn = isOn
        self.tint = tint
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(isOn ? tint : Color.DS.segmentOff)
            .frame(width: 14, height: 8)
    }
}

#Preview {
    HStack(spacing: 3) {
        StatSegment(isOn: true, tint: TypeTint.grass.color)
        StatSegment(isOn: false, tint: TypeTint.grass.color)
    }
    .padding()
    .background(Color.DS.lcd)
}
