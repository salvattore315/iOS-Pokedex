import Foundation
import Testing
@testable import Networking

private struct ItemEndpoint: Endpoint {
    var id = 1
    var method: HTTPMethod = .get
    var baseURL: URL { URL(string: "https://api.example.com")! }
    var path: String { "items/\(id)" }
}

private struct Item: Decodable, Sendable, Equatable {
    let id: Int
    let displayName: String
}

private let itemJSON = Data(#"{"id": 1, "display_name": "Bulbasaur"}"#.utf8)

/// Runs serially because every test shares the global `URLProtocolStub` handler.
@Suite(.serialized)
struct HTTPClientTests {
    private func makeClient(cache: ResponseCache? = nil) -> URLSessionHTTPClient {
        URLSessionHTTPClient(session: URLProtocolStub.makeSession(), cache: cache)
    }

    @Test func decodesSuccessfulResponseWithSnakeCaseKeys() async throws {
        URLProtocolStub.reset { _ in (.stub(200), itemJSON) }
        let item: Item = try await makeClient().send(ItemEndpoint())
        #expect(item == Item(id: 1, displayName: "Bulbasaur"))
    }

    @Test(arguments: [404, 500, 429])
    func mapsNonSuccessStatusCodes(statusCode: Int) async {
        URLProtocolStub.reset { _ in (.stub(statusCode), Data()) }
        let error = await caughtError { () async throws(APIError) in _ = try await makeClient().data(for: ItemEndpoint()) }
        guard case .http(let code) = error else {
            Issue.record("Expected .http, got \(String(describing: error))")
            return
        }
        #expect(code == statusCode)
    }

    @Test func reportsDecodingFailures() async {
        URLProtocolStub.reset { _ in (.stub(200), Data("not json".utf8)) }
        let error = await caughtError { () async throws(APIError) in let _: Item = try await makeClient().send(ItemEndpoint()) }
        guard case .decoding(let underlying) = error else {
            Issue.record("Expected .decoding, got \(String(describing: error))")
            return
        }
        #expect(underlying is DecodingError)
    }

    @Test func mapsOfflineErrors() async {
        URLProtocolStub.reset { _ in throw URLError(.notConnectedToInternet) }
        let error = await caughtError { () async throws(APIError) in _ = try await makeClient().data(for: ItemEndpoint()) }
        guard case .offline = error else {
            Issue.record("Expected .offline, got \(String(describing: error))")
            return
        }
    }

    @Test func servesRepeatedGetFromCache() async throws {
        URLProtocolStub.reset { _ in (.stub(200), itemJSON) }
        let client = makeClient(cache: ResponseCache())
        _ = try await client.data(for: ItemEndpoint())
        _ = try await client.data(for: ItemEndpoint())
        #expect(URLProtocolStub.requests.count == 1)
    }

    @Test func deduplicatesConcurrentGetRequests() async throws {
        URLProtocolStub.reset { _ in
            Thread.sleep(forTimeInterval: 0.2)
            return (.stub(200), itemJSON)
        }
        let client = makeClient(cache: ResponseCache())
        async let first = client.data(for: ItemEndpoint())
        async let second = client.data(for: ItemEndpoint())
        _ = try await (first, second)
        #expect(URLProtocolStub.requests.count == 1)
    }

    @Test func neverCachesNonGetRequests() async throws {
        URLProtocolStub.reset { _ in (.stub(200), itemJSON) }
        let client = makeClient(cache: ResponseCache())
        _ = try await client.data(for: ItemEndpoint(method: .post))
        _ = try await client.data(for: ItemEndpoint(method: .post))
        #expect(URLProtocolStub.requests.count == 2)
    }

    @Test func doesNotCacheFailures() async throws {
        URLProtocolStub.reset { _ in (.stub(500), Data()) }
        let client = makeClient(cache: ResponseCache())
        _ = try? await client.data(for: ItemEndpoint())
        URLProtocolStub.handler = { _ in (.stub(200), itemJSON) }
        let data = try await client.data(for: ItemEndpoint())
        #expect(data == itemJSON)
        #expect(URLProtocolStub.requests.count == 2)
    }
}
