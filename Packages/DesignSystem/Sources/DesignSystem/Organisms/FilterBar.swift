import SwiftUI

/// Horizontally scrolling row of filters with an "All" option first.
public struct FilterBar<ID: Hashable>: View {
    /// One filter: identifier, text and optional type color.
    public struct Option: Identifiable {
        public let id: ID
        public let label: String
        public let tint: Color?

        public init(id: ID, label: String, tint: Color? = nil) {
            self.id = id
            self.label = label
            self.tint = tint
        }
    }

    private let allLabel: String
    private let options: [Option]
    @Binding private var selection: ID?

    /// - Parameter selection: `nil` means "All".
    public init(allLabel: String, options: [Option], selection: Binding<ID?>) {
        self.allLabel = allLabel
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(allLabel, isSelected: selection == nil) { selection = nil }
                ForEach(options) { option in
                    FilterChip(option.label, tint: option.tint, isSelected: selection == option.id) {
                        selection = option.id
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: TypeTint?
    FilterBar(
        allLabel: "All",
        options: TypeTint.allCases.map { .init(id: $0, label: $0.rawValue, tint: $0.color) },
        selection: $selection
    )
    .padding()
    .background(Color.DS.viewer)
}
