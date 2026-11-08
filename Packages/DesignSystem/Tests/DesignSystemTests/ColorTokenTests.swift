import Testing
import UIKit
@testable import DesignSystem

struct ColorTokenTests {
    private let tokens = [
        "shell", "viewer", "surface", "surfaceMuted", "module", "panel", "lcd", "lcdText", "segmentOff",
        "border", "accent", "accentText", "onAccent", "textPrimary", "textSecondary", "onShell", "danger",
    ]

    @Test func everyTokenExistsInTheAssetCatalog() {
        for name in tokens {
            #expect(UIColor(named: name, in: .module, compatibleWith: nil) != nil, "Missing colorset \(name)")
        }
    }

    @Test func shellChangesInDarkMode() throws {
        let color = try #require(UIColor(named: "shell", in: .module, compatibleWith: nil))
        let light = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        #expect(light != dark)
    }

    @Test func thereAreEighteenTypeTints() {
        #expect(TypeTint.allCases.count == 18)
        #expect(TypeTint(rawValue: "grass") == .grass)
    }
}
