import CoreText
import SwiftUI

public extension Font {
    /// JetBrains Mono, the device-style monospaced font used for titles, numbers and labels.
    /// The font files are bundled with the package and registered the first time this is called.
    static func mono(_ size: CGFloat, weight: MonoWeight = .medium) -> Font {
        FontRegistration.registerOnce()
        return .custom(weight.postScriptName, size: size)
    }

    /// Weights bundled with the package.
    enum MonoWeight: Sendable {
        case medium, bold

        var postScriptName: String {
            switch self {
            case .medium: "JetBrainsMono-Medium"
            case .bold: "JetBrainsMono-Bold"
            }
        }
    }
}

/// Registers the bundled fonts with Core Text exactly once per process.
enum FontRegistration {
    private static let registration: Void = {
        let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func registerOnce() {
        _ = registration
    }
}
