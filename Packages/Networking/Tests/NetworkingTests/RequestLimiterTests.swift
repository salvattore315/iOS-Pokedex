import Foundation
import Testing
@testable import Networking

/// Records the order in which tasks got a slot.
private actor Order {
    private(set) var names: [String] = []
    func append(_ name: String) { names.append(name) }
}

struct RequestLimiterTests {
    @Test func neverRunsMoreThanTheCap() async throws {
        let limiter = RequestLimiter(maxConcurrent: 3)
        let peak = Peak()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await limiter.acquire()
                    await peak.enter()
                    try await Task.sleep(for: .milliseconds(5))
                    await peak.leave()
                    await limiter.release()
                }
            }
            try await group.waitForAll()
        }

        #expect(await peak.maximum == 3)
        #expect(await limiter.running == 0)
    }

    @Test func givesTheFreeSlotToTheHighestPriorityWaiter() async throws {
        let limiter = RequestLimiter(maxConcurrent: 1)
        let order = Order()
        try await limiter.acquire()

        // Cards queue first, at low priority; the detail request arrives last.
        let low1 = Task(priority: .low) { try await limiter.acquire(); await order.append("card-1"); await limiter.release() }
        while await limiter.waitingCount < 1 { await Task.yield() }
        let low2 = Task(priority: .low) { try await limiter.acquire(); await order.append("card-2"); await limiter.release() }
        while await limiter.waitingCount < 2 { await Task.yield() }
        let high = Task(priority: .userInitiated) { try await limiter.acquire(); await order.append("detail"); await limiter.release() }
        while await limiter.waitingCount < 3 { await Task.yield() }

        await limiter.release()
        _ = try await (low1.value, low2.value, high.value)

        #expect(await order.names == ["detail", "card-1", "card-2"])
    }

    @Test func cancelledWaiterLeavesTheQueueWithoutTakingASlot() async throws {
        let limiter = RequestLimiter(maxConcurrent: 1)
        try await limiter.acquire()
        let waiter = Task { try await limiter.acquire() }
        while await limiter.waitingCount < 1 { await Task.yield() }

        waiter.cancel()

        await #expect(throws: CancellationError.self) { try await waiter.value }
        #expect(await limiter.waitingCount == 0)
        await limiter.release()
        #expect(await limiter.running == 0)
    }

    @Test func throwsWithoutWaitingWhenAlreadyCancelled() async {
        let limiter = RequestLimiter(maxConcurrent: 1)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await limiter.acquire()
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await limiter.running == 0)
    }
}

/// Tracks how many tasks are inside the limited section at once.
private actor Peak {
    private var current = 0
    private(set) var maximum = 0
    func enter() { current += 1; maximum = max(maximum, current) }
    func leave() { current -= 1 }
}
