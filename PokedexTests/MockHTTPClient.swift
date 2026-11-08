import Foundation
import Networking
@testable import Pokedex

/// ``HTTPClient`` that answers from fixtures keyed by URL path, without touching the network.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String: Result<String, APIError>] = [:]
    private(set) var requestedPaths: [String] = []

    /// Answers requests whose URL path ends with `pathSuffix` with `json`.
    func stub(_ pathSuffix: String, json: String) {
        lock.withLock { responses[pathSuffix] = .success(json) }
    }

    /// Answers requests whose URL path ends with `pathSuffix` with `error`.
    func stub(_ pathSuffix: String, error: APIError) {
        lock.withLock { responses[pathSuffix] = .failure(error) }
    }

    func data(for endpoint: some Endpoint) async throws(APIError) -> Data {
        let path = try endpoint.makeRequest().url?.path() ?? ""
        // PokéAPI links end with "/" (for example ".../evolution-chain/1/"); stubs are written without it.
        let matchPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        let response: Result<String, APIError>? = lock.withLock {
            requestedPaths.append(path)
            return responses.first { matchPath.hasSuffix($0.key) }?.value
        }
        switch response {
        case .success(let json): return Data(json.utf8)
        case .failure(let error): throw error
        case nil: throw .http(statusCode: 404)
        }
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
