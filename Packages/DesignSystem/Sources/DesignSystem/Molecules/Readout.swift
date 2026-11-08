import SwiftUI

/// Small labelled value: height, weight, habitat.
public struct Readout: View {
    private let label: String
    private let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label.uppercased()).font(.mono(10)).foregroundStyle(Color.DS.accentText)
            Text(value).font(.mono(14)).foregroundStyle(Color.DS.textPrimary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(Color.DS.panel, in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.DS.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack { Readout(label: "Height", value: "0.7 m"); Readout(label: "Weight", value: "6.9 kg") }.padding()
}
