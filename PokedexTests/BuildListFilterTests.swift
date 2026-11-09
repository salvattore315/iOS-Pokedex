import Testing
@testable import Pokedex

struct BuildListFilterTests {
    @Test func blankQueryIsEmptyFilter() {
        #expect(BuildListFilter.make(query: "  ", typeIDs: nil, generationIDs: nil).isEmpty)
    }

    @Test func lowercasesName() {
        #expect(BuildListFilter.make(query: " Pika ", typeIDs: nil, generationIDs: nil) == ListFilter(name: "pika"))
    }

    @Test(arguments: ["25", "#25", "#025"])
    func parsesNumber(_ query: String) {
        #expect(BuildListFilter.make(query: query, typeIDs: nil, generationIDs: nil) == ListFilter(number: 25))
    }

    @Test func intersectsTypeAndGeneration() {
        let filter = BuildListFilter.make(query: "", typeIDs: [1, 4, 25], generationIDs: [1, 25, 250])
        #expect(filter.ids == [1, 25])
    }
}
