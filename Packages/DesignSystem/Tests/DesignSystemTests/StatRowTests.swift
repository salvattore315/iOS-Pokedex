import SwiftUI
import Testing
@testable import DesignSystem

struct StatRowTests {
    @Test(arguments: [(0, 0), (1, 1), (45, 2), (128, 5), (255, 10), (300, 10)])
    func litSegments(value: Int, expected: Int) {
        #expect(StatRow.litSegments(for: value) == expected)
    }

    @Test func formatsNumbersWithThreeDigits() {
        #expect(PokemonCard<EmptyView>.formatted(1) == "#001")
        #expect(PokemonCard<EmptyView>.formatted(1025) == "#1025")
    }
}
