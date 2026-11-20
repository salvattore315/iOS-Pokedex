import Foundation

/// Caps how many requests run at the same time and hands each free slot to the
/// waiting request with the highest task priority (first come, first served among equals).
///
/// Without a cap, dozens of background requests share the bandwidth with the one the
/// user is waiting for. With it, a high-priority request waits at most for one slot.
public actor RequestLimiter {
    private struct Waiter {
        let id: UInt64
        let priority: TaskPriority
        let continuation: CheckedContinuation<Void, any Error>
    }

    public let maxConcurrent: Int
    private(set) var running = 0
    private var waiters: [Waiter] = []
    private var nextID: UInt64 = 0

    /// - Parameter maxConcurrent: How many requests may run at once. Must be at least 1.
    public init(maxConcurrent: Int) {
        precondition(maxConcurrent > 0, "maxConcurrent must be at least 1")
        self.maxConcurrent = maxConcurrent
    }

    /// Number of requests waiting for a slot.
    var waitingCount: Int { waiters.count }

    /// Waits for a free slot. Every successful call must be balanced by ``release()``.
    /// Throws `CancellationError` if the task is cancelled while waiting; no slot is taken then.
    public func acquire() async throws {
        try Task.checkCancellation()
        if running < maxConcurrent {
            running += 1
            return
        }
        nextID += 1
        let id = nextID
        let priority = Task.currentPriority
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                waiters.append(Waiter(id: id, priority: priority, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    /// Frees a slot, handing it straight to the highest-priority waiter if there is one.
    public func release() {
        guard let index = indexOfNextWaiter() else {
            running -= 1
            return
        }
        // The slot passes to the waiter, so `running` stays the same.
        waiters.remove(at: index).continuation.resume()
    }

    private func indexOfNextWaiter() -> Int? {
        guard var best = waiters.indices.first else { return nil }
        for index in waiters.indices.dropFirst() where waiters[index].priority > waiters[best].priority {
            best = index
        }
        return best
    }

    private func cancelWaiter(id: UInt64) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
