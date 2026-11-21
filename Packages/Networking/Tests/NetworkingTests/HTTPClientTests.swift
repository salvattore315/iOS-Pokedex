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
    private func makeClient(cache: ResponseCache? = nil, limiter: RequestLimiter? = nil) -> URLSessionHTTPClient {
        URLSessionHTTPClient(session: URLProtocolStub.makeSession(), cache: cache, limiter: limiter)
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

    @Test func completesEveryRequestThroughTheLimiterAndFreesItsSlots() async throws {
        URLProtocolStub.reset { _ in (.stub(200), itemJSON) }
        let limiter = RequestLimiter(maxConcurrent: 2)
        let client = makeClient(limiter: limiter)

        try await withThrowingTaskGroup(of: Data.self) { group in
            for id in 1...10 {
                group.addTask { try await client.data(for: ItemEndpoint(id: id)) }
            }
            for try await data in group { #expect(data == itemJSON) }
        }

        #expect(URLProtocolStub.requests.count == 10)
        #expect(await limiter.running == 0)
    }

    @Test func freesTheSlotWhenARequestFails() async throws {
        URLProtocolStub.reset { _ in (.stub(500), Data()) }
        let limiter = RequestLimiter(maxConcurrent: 1)
        let client = makeClient(limiter: limiter)
        _ = try? await client.data(for: ItemEndpoint())
        #expect(await limiter.running == 0)
    }

    @Test func passesTheTaskPriorityToTheURLSessionTask() async throws {
        URLProtocolStub.reset { _ in (.stub(200), itemJSON) }
        let client = makeClient()
        _ = try await Task(priority: .userInitiated) { try await client.data(for: ItemEndpoint(id: 1)) }.value
        // Awaiting `value` would escalate the task's priority, so wait for the request to arrive instead.
        Task(priority: .utility) { _ = try await client.data(for: ItemEndpoint(id: 2)) }
        while URLProtocolStub.priorities.all.count < 2 { await Task.yield() }
        #expect(URLProtocolStub.priorities.all == [URLSessionTask.highPriority, URLSessionTask.lowPriority])
    }

    // MARK: - Stalled connections

    @Test(arguments: [URLError.Code.timedOut, .networkConnectionLost])
    func retriesAStalledGetOnce(code: URLError.Code) async throws {
        let calls = RequestLog()
        URLProtocolStub.reset { request in
            calls.record(request)
            if calls.count == 1 { throw URLError(code) }
            return (.stub(200), itemJSON)
        }
        let data = try await makeClient().data(for: ItemEndpoint())
        #expect(data == itemJSON)
        #expect(URLProtocolStub.requests.count == 2)
    }

    @Test func reportsTimeoutWhenTheRetryAlsoStalls() async {
        URLProtocolStub.reset { _ in throw URLError(.timedOut) }
        let error = await caughtError { () async throws(APIError) in _ = try await makeClient().data(for: ItemEndpoint()) }
        guard case .timeout = error else {
            Issue.record("Expected .timeout, got \(String(describing: error))")
            return
        }
        #expect(URLProtocolStub.requests.count == 2)
    }

    @Test func neverRetriesNonGetRequests() async {
        URLProtocolStub.reset { _ in throw URLError(.timedOut) }
        _ = await caughtError { () async throws(APIError) in _ = try await makeClient().data(for: ItemEndpoint(method: .post)) }
        #expect(URLProtocolStub.requests.count == 1)
    }

    @Test func doesNotRetryOtherFailures() async {
        URLProtocolStub.reset { _ in throw URLError(.notConnectedToInternet) }
        _ = await caughtError { () async throws(APIError) in _ = try await makeClient().data(for: ItemEndpoint()) }
        #expect(URLProtocolStub.requests.count == 1)
    }
}

/// The session the app uses instead of `URLSession.shared`.
struct SessionConfigurationTests {
    @Test func keepsTheGivenDiskCache() {
        let cache = URLCache(memoryCapacity: 0, diskCapacity: 1024 * 1024)
        let configuration = URLSessionHTTPClient.makeConfiguration(urlCache: cache)
        #expect(configuration.urlCache === cache)
        #expect(configuration.requestCachePolicy == .useProtocolCachePolicy)
    }

    @Test func usesTheSharedCacheByDefault() {
        #expect(URLSessionHTTPClient.makeConfiguration().urlCache === URLCache.shared)
    }

    @Test func failsFastInsteadOfHanging() {
        let configuration = URLSessionHTTPClient.makeConfiguration()
        #expect(configuration.timeoutIntervalForRequest == URLSessionHTTPClient.defaultTimeout)
        #expect(configuration.timeoutIntervalForResource == 60)
        #expect(!configuration.waitsForConnectivity)
        #expect(configuration.httpMaximumConnectionsPerHost == 4)
    }

    @Test func sessionUsesTheConfiguration() {
        let cache = URLCache(memoryCapacity: 0, diskCapacity: 1024 * 1024)
        let session = URLSessionHTTPClient.makeSession(urlCache: cache)
        #expect(session !== URLSession.shared)
        #expect(session.configuration.urlCache === cache)
        #expect(session.configuration.timeoutIntervalForRequest == URLSessionHTTPClient.defaultTimeout)
    }
}
