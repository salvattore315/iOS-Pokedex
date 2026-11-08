import SwiftUI

/// Search box of the list screen.
public struct SearchField: View {
    @Binding private var text: String
    private let prompt: String

    public init(text: Binding<String>, prompt: String) {
        self._text = text
        self.prompt = prompt
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.DS.textSecondary)
            TextField(text: $text) {
                Text(prompt.uppercased()).font(.mono(12)).foregroundStyle(Color.DS.textSecondary)
            }
            .font(.mono(12))
            .foregroundStyle(Color.DS.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.DS.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear", bundle: .module))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .background(Color.DS.viewer, in: .rect(cornerRadius: 6))
    }
}

#Preview {
    @Previewable @State var text = ""
    SearchField(text: $text, prompt: "Search name or number").padding().background(Color.DS.shell)
}
