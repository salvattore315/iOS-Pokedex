import XCTest

final class PokedexUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() {
        let app = XCUIApplication.withFixtures()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    /// List → search → detail → mark as favorite → favorites tab → open it → remove it.
    @MainActor
    func testFavoriteFlow() {
        let app = XCUIApplication.withFixtures()
        app.launch()

        // List
        let bulbasaur = card(named: "Bulbasaur", in: app)
        let charmander = card(named: "Charmander", in: app)
        XCTAssertTrue(bulbasaur.waitForExistence(timeout: 10))
        XCTAssertTrue(charmander.exists)

        // Search
        search("bulb", in: app)
        XCTAssertTrue(charmander.waitForNonExistence(timeout: 5))
        XCTAssertTrue(bulbasaur.exists)

        // Detail, then mark as favorite
        bulbasaur.tap()
        XCTAssertTrue(app.staticTexts["Seed Pokémon"].waitForExistence(timeout: 5))
        app.buttons["Add to favorites"].tap()
        XCTAssertTrue(app.buttons["Remove from favorites"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()

        // Favorites tab
        app.tabBars.buttons["Favorites"].tap()
        let favorite = app.cells.containing(.staticText, identifier: "Bulbasaur").firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))

        // The detail opened from the favorites tab knows it is a favorite.
        favorite.tap()
        XCTAssertTrue(app.buttons["Remove from favorites"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()

        // Swipe to remove
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.swipeLeft()
        app.buttons["Remove"].tap()
        XCTAssertTrue(app.staticTexts["NO FAVORITES YET"].waitForExistence(timeout: 5))
    }

    /// Unfavoriting from the detail screen updates the favorites tab when coming back.
    @MainActor
    func testRemovingFromDetailUpdatesFavorites() {
        let app = XCUIApplication.withFixtures()
        app.launch()

        let bulbasaur = card(named: "Bulbasaur", in: app)
        XCTAssertTrue(bulbasaur.waitForExistence(timeout: 10))
        bulbasaur.tap()
        XCTAssertTrue(app.staticTexts["Seed Pokémon"].waitForExistence(timeout: 5))
        app.buttons["Add to favorites"].tap()
        XCTAssertTrue(app.buttons["Remove from favorites"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Favorites"].tap()
        let favorite = app.cells.containing(.staticText, identifier: "Bulbasaur").firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.tap()
        app.buttons["Remove from favorites"].tap()
        XCTAssertTrue(app.buttons["Add to favorites"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()

        XCTAssertTrue(app.staticTexts["NO FAVORITES YET"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    /// A card of the list grid. Cards combine their texts into one accessibility element.
    @MainActor
    private func card(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    @MainActor
    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // Typing before the field has focus loses the text.
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed)
        field.typeText(text)
    }
}
