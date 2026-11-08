import Foundation
import Testing
@testable import Networking

private struct ListEndpoint: Endpoint {
    var baseURL: URL { URL(string: "https://pokeapi.co/api/v2")! }
    var path: String { "pokemon" }
    var queryItems: [URLQueryItem] { [.init(name: "offset", value: "20"), .init(name: "limit", value: "20")] }
}

private struct PostEndpoint: Endpoint {
    var baseURL: URL { URL(string: "https://example.com")! }
    var path: String { "items" }
    var method: HTTPMethod { .post }
    var headers: [String: String] { ["Authorization": "Bearer token"] }
    var body: Data? { Data("{}".utf8) }
}

struct EndpointTests {
    @Test func buildsURLWithPathAndQuery() throws {
        let request = try ListEndpoint().makeRequest()
        #expect(request.url?.absoluteString == "https://pokeapi.co/api/v2/pokemon?offset=20&limit=20")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func appliesMethodHeadersAndBody() throws {
        let request = try PostEndpoint().makeRequest()
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.httpBody == Data("{}".utf8))
    }

    @Test func absoluteURLEndpointKeepsItsQuery() throws {
        let url = URL(string: "https://pokeapi.co/api/v2/pokemon?offset=40&limit=20")!
        let request = try URLEndpoint(url).makeRequest()
        #expect(request.url == url)
    }

    @Test func usesCustomTimeout() throws {
        let request = try ListEndpoint().makeRequest(timeout: 5)
        #expect(request.timeoutInterval == 5)
    }
}

struct APIErrorTests {
    @Test func mapsOfflineURLErrors() {
        for code: URLError.Code in [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed] {
            guard case .offline = APIError(URLError(code)) else {
                Issue.record("Expected .offline for \(code)")
                continue
            }
        }
    }

    @Test func mapsTimeoutCancelAndBadURL() {
        guard case .timeout = APIError(URLError(.timedOut)) else { Issue.record("Expected .timeout"); return }
        guard case .cancelled = APIError(URLError(.cancelled)) else { Issue.record("Expected .cancelled"); return }
        guard case .invalidURL = APIError(URLError(.badURL)) else { Issue.record("Expected .invalidURL"); return }
    }

    @Test func classifiesRetryableErrors() {
        #expect(APIError.offline.isRetryable)
        #expect(APIError.http(statusCode: 503).isRetryable)
        #expect(APIError.http(statusCode: 429).isRetryable)
        #expect(!APIError.http(statusCode: 404).isRetryable)
        #expect(APIError.http(statusCode: 404).isNotFound)
    }
}

struct APIErrorUnderlyingTests {
    @Test func keepsOriginalTransportError() {
        let original = URLError(.cannotFindHost)
        guard case .transport(let kept) = APIError(original) else {
            Issue.record("Expected .transport")
            return
        }
        #expect(kept.code == .cannotFindHost)
    }

    @Test func keepsOriginalDecodingError() throws {
        struct Model: Decodable { let id: Int }
        do {
            _ = try JSONDecoder().decode(Model.self, from: Data("{}".utf8))
            Issue.record("Expected decoding to fail")
        } catch {
            let apiError = APIError.decoding(error)
            guard case .decoding(let underlying) = apiError else { return }
            #expect(underlying is DecodingError)
        }
    }
}
