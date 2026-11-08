import SwiftUI

/// Placeholder card shown while the list loads. Same size as ``PokemonCard``.
public struct SkeletonCard: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            bone(height: 100)
            bone(width: 100, height: 12)
            bone(width: 60, height: 12)
        }
        .padding(Spacing.sm)
        .background(Color.DS.surface, in: .rect(cornerRadius: Radius.md))
        .shimmering()
        .accessibilityLabel(Text("Loading", bundle: .module))
    }

    private func bone(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Radius.sm)
            .fill(Color.DS.surfaceMuted)
            .frame(maxWidth: width ?? .infinity, alignment: .leading)
            .frame(width: width, height: height)
    }
}

/// Soft pulsing opacity used on loading placeholders. Disabled with Reduce Motion.
struct Shimmer: ViewModifier {
    @State private var isDimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isDimmed ? 0.55 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { isDimmed = true }
            }
    }
}

public extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

#Preview {
    LazyVGrid(columns: [GridItem(), GridItem()]) {
        ForEach(0..<4, id: \.self) { _ in SkeletonCard() }
    }
    .padding()
    .background(Color.DS.viewer)
}
