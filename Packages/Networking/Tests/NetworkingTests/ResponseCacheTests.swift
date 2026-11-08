import Foundation
import Testing
@testable import Networking

/// Counts how many times a load closure runs, from any task.
private actor LoadCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

struct ResponseCacheTests {
    private let url = URL(string: "https://api.example.com/items/1")!

    @Test func runsLoadOnceForConcurrentCallers() async throws {
        let cache = ResponseCache()
        let counter = LoadCounter()
        let load: @Sendable () async throws -> Data = {
            await counter.increment()
            try await Task.sleep(for: .milliseconds(200))
            return Data("payload".utf8)
        }

        async let a = cache.data(for: url, load: load)
        async let b = cache.data(for: url, load: load)
        async let c = cache.data(for: url, load: load)
        let results = try await [a, b, c]

        #expect(results.allSatisfy { $0 == Data("payload".utf8) })
        #expect(await counter.value == 1)
    }

    @Test func reloadsAfterRemoveAll() async throws {
        let cache = ResponseCache()
        let counter = LoadCounter()
        let load: @Sendable () async throws -> Data = {
            await counter.increment()
            return Data()
        }

        _ = try await cache.data(for: url, load: load)
        await cache.removeAll()
        _ = try await cache.data(for: url, load: load)

        #expect(await counter.value == 2)
    }

    @Test func retriesAfterAFailedLoad() async throws {
        struct Failure: Error {}
        let cache = ResponseCache()

        await #expect(throws: Failure.self) {
            _ = try await cache.data(for: url) { throw Failure() }
        }
        let data = try await cache.data(for: url) { Data("ok".utf8) }
        #expect(data == Data("ok".utf8))
    }
}
