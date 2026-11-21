import XCTest

extension XCUIApplication {
    /// An app that skips the splash video, speaks English and answers every PokéAPI request
    /// from the JSON files in `PokedexUITests/Fixtures`, so the tests never hit the network.
    /// SwiftData is kept in memory, so every launch starts without favorites.
    static func withFixtures() -> XCUIApplication {
        let app = XCUIApplication()
        // Keep in sync with SplashVideoView.skipLaunchArgument and UITestLaunch.
        app.launchArguments += ["-skipSplash", "-stubNetwork", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["STUB_FIXTURES"] = fixturesJSON()
        return app
    }

    /// Every fixture as one JSON object: file name without extension → file contents.
    private static func fixturesJSON() -> String {
        final class BundleToken {}
        let urls = Bundle(for: BundleToken.self).urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        var fixtures: [String: String] = [:]
        for url in urls {
            fixtures[url.deletingPathExtension().lastPathComponent] = try? String(contentsOf: url, encoding: .utf8)
        }
        let data = (try? JSONSerialization.data(withJSONObject: fixtures)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
