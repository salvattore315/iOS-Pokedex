import SwiftUI

/// Scanner screen of the detail: dot grid, artwork, "SCAN ▸ ACTIVE" label, ID and a sweeping scan line.
public struct ScanViewer<Artwork: View>: View {
    private let number: Int
    private let tint: Color
    private let artwork: Artwork
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(number: Int, tint: Color, @ViewBuilder artwork: () -> Artwork) {
        self.number = number
        self.tint = tint
        self.artwork = artwork()
    }

    public var body: some View {
        ZStack {
            tint.opacity(0.18)
            DotGrid().foregroundStyle(Color.DS.textSecondary.opacity(0.35))
            artwork.padding(Spacing.xl)
            if !reduceMotion { ScanLine(tint: tint) }
        }
        .overlay(alignment: .topLeading) { label(String(localized: "SCAN ▸ ACTIVE", bundle: .module)) }
        .overlay(alignment: .bottomTrailing) { label("ID " + String(format: "%04d", number)) }
        .frame(height: 190)
        .clipShape(.rect(cornerRadius: Radius.md))
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.mono(9)).foregroundStyle(Color.DS.lcdText).padding(Spacing.sm).accessibilityHidden(true)
    }
}

/// Regular grid of small dots drawn with `Canvas`.
struct DotGrid: View {
    var spacing: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .foreground)
                    x += spacing
                }
                y += spacing
            }
        }
        .accessibilityHidden(true)
    }
}

/// Horizontal line that sweeps up and down, driven by `TimelineView`.
struct ScanLine: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let period = 2.4
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                let progress = phase < 0.5 ? phase * 2 : 2 - phase * 2
                Rectangle()
                    .fill(tint)
                    .frame(height: 2)
                    .shadow(color: tint, radius: 4)
                    .offset(y: progress * (proxy.size.height - 2))
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ScanViewer(number: 1, tint: TypeTint.grass.color) {
        Circle().fill(TypeTint.grass.color.opacity(0.6))
    }
    .padding()
}
