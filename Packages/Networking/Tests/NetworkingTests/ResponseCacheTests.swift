import Foundation
import Testing
@testable import Networking

/// Counts how many times a load closure runs, from any task.
private actor LoadCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

/// A load that runs until it is cancelled, and records whether it was.
private actor ControlledLoad {
    private(set) var started = 0
    private(set) var wasCancelled = false

    func run() async throws -> Data {
        started += 1
        do {
            try await Task.sleep(for: .seconds(10))
        } catch {
            wasCancelled = true
            throw error
        }
        return Data("payload".utf8)
    }

    /// Waits until `run()` has started `count` times.
    func waitUntilStarted(_ count: Int = 1) async {
        while started < count { await Task.yield() }
    }
}

/// A load that finishes when `finish()` is called, unless it is cancelled first.
private actor GatedLoad {
    private(set) var started = false
    private(set) var wasCancelled = false
    private var gate: CheckedContinuation<Void, Never>?

    func run() async throws -> Data {
        started = true
        await withCheckedContinuation { gate = $0 }
        if Task.isCancelled {
            wasCancelled = true
            throw CancellationError()
        }
        return Data("payload".utf8)
    }

    func finish() {
        gate?.resume()
        gate = nil
    }

    func waitUntilStarted() async {
        while !started || gate == nil { await Task.yield() }
    }
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

    @Test func cancelsTheLoadWhenItsOnlyCallerIsCancelled() async throws {
        let cache = ResponseCache()
        let load = ControlledLoad()
        let caller = Task { try await cache.data(for: url) { try await load.run() } }
        await load.waitUntilStarted()

        caller.cancel()

        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(await load.wasCancelled)
    }

    @Test func keepsLoadingWhileAnotherCallerStillWaits() async throws {
        let cache = ResponseCache()
        let load = GatedLoad()
        let cancelled = Task { try await cache.data(for: url) { try await load.run() } }
        await load.waitUntilStarted()
        let waiting = Task { try await cache.data(for: url) { try await load.run() } }
        // Let the second caller join the load in flight before cancelling the first.
        while await cache.callerCount(for: url) < 2 { await Task.yield() }

        cancelled.cancel()
        try await Task.sleep(for: .milliseconds(50))
        await load.finish()

        #expect(try await waiting.value == Data("payload".utf8))
        #expect(await load.wasCancelled == false)
    }

    @Test func startsAFreshLoadAfterACancelledOne() async throws {
        let cache = ResponseCache()
        let load = ControlledLoad()
        let caller = Task { try await cache.data(for: url) { try await load.run() } }
        await load.waitUntilStarted()
        caller.cancel()
        _ = try? await caller.value

        let data = try await cache.data(for: url) { Data("fresh".utf8) }
        #expect(data == Data("fresh".utf8))
    }
}
