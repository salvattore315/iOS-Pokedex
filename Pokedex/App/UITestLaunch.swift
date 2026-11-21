#if DEBUG
import Foundation
import Networking

/// Launch options for UI tests. Only compiled in debug builds.
///
/// With `-stubNetwork`, every PokéAPI request is answered from the fixtures in the
/// `STUB_FIXTURES` environment variable, and SwiftData keeps everything in memory,
/// so each launch starts clean and the tests never depend on PokéAPI.
enum UITestLaunch {
    /// Keep in sync with the UI tests.
    static let stubNetworkArgument = "-stubNetwork"
    /// A JSON object: fixture name → response body. See ``FixtureHTTPClient`` for the names.
    static let fixturesEnvironmentKey = "STUB_FIXTURES"

    /// The dependencies for a stubbed launch, or `nil` for a normal one.
    static func dependencies(processInfo: ProcessInfo = .processInfo) -> AppDependencies? {
        guard processInfo.arguments.contains(stubNetworkArgument) else { return nil }
        let json = processInfo.environment[fixturesEnvironmentKey] ?? "{}"
        let fixtures = (try? JSONDecoder().decode([String: String].self, from: Data(json.utf8))) ?? [:]
        return AppDependencies.make(client: FixtureHTTPClient(fixtures: fixtures), mode: .local, isStoredInMemoryOnly: true)
    }
}

/// ``HTTPClient`` that answers from fixtures instead of the network.
///
/// A fixture is named after the URL path that follows `/api/v2/`, with `/` replaced by `_`
/// and the query ignored: `pokemon/1/encounters` → `pokemon_1_encounters`.
/// A request without a fixture fails with HTTP 404.
struct FixtureHTTPClient: HTTPClient {
    let fixtures: [String: String]

    static func name(for url: URL) -> String {
        let path = url.path()
        let relative = path.range(of: "/api/v2/").map { String(path[$0.upperBound...]) } ?? path
        return relative
            .split(separator: "/")
            .joined(separator: "_")
    }

    func data(for endpoint: some Endpoint) async throws(APIError) -> Data {
        guard let url = try endpoint.makeRequest().url, let body = fixtures[Self.name(for: url)] else {
            throw .http(statusCode: 404)
        }
        return Data(body.utf8)
    }

    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint, as type: T.Type) async throws(APIError) -> T {
        let data = try await data(for: endpoint)
        do {
            return try URLSessionHTTPClient.defaultDecoder().decode(T.self, from: data)
        } catch {
            throw .decoding(error)
        }
    }
}
#endif
