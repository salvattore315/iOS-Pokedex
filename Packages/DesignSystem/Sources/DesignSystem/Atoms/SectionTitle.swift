import SwiftUI

/// Section heading of the information module, with a yellow underline.
public struct SectionTitle: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(.mono(11, weight: .bold))
                .foregroundStyle(Color.DS.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(Color.DS.accent)
                .frame(height: 2)
        }
    }
}

#Preview {
    SectionTitle("About").padding().background(Color.DS.module)
}
