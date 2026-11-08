import SwiftUI

/// Empty, error and no-results states: icon, title, message and an optional action.
public struct StateMessage: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(systemImage: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.DS.textSecondary)
            Text(title.uppercased()).font(.mono(13, weight: .bold)).foregroundStyle(Color.DS.textPrimary)
            Text(message).font(.system(size: 12)).foregroundStyle(Color.DS.textSecondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.accent).padding(.top, Spacing.xs)
            }
        }
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: 300)
    }
}

#Preview {
    StateMessage(systemImage: "wifi.slash", title: "No connection", message: "Check your connection and try again.", actionTitle: "Retry") {}
        .background(Color.DS.viewer)
}
