import Testing
import UIKit
@testable import DesignSystem

struct TypographyTests {
    @Test func registersBundledFonts() {
        FontRegistration.registerOnce()
        #expect(UIFont(name: "JetBrainsMono-Medium", size: 12) != nil)
        #expect(UIFont(name: "JetBrainsMono-Bold", size: 12) != nil)
    }
}
