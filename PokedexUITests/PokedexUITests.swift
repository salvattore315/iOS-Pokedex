import XCTest

final class PokedexUITests: XCTestCase {
    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        // Keep in sync with SplashVideoView.skipLaunchArgument.
        app.launchArguments.append("-skipSplash")
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }
}
