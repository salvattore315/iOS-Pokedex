import Foundation

/// In-memory cache for response bodies that also deduplicates requests in flight.
///
/// - Completed responses are kept in an `NSCache`, which evicts entries under memory pressure.
/// - While a URL is loading, other callers asking for the same URL await the same task
///   instead of starting a second request.
/// - When every caller waiting for a load is cancelled, the load is cancelled too, so
///   requests nobody needs any more (for example, cards scrolled off screen) stop using the network.
/// - Failed loads are never cached, so the next call tries again.
public actor ResponseCache {
    /// A shared load and how many of its callers are still interested in it.
    private struct Load {
        let task: Task<Data, any Error>
        var callers: Int
        var cancelledCallers = 0
    }

    private let storage = NSCache<NSURL, NSData>()
    private var inFlight: [URL: Load] = [:]

    /// - Parameters:
    ///   - countLimit: Maximum number of cached responses.
    ///   - totalCostLimit: Maximum total size of cached responses, in bytes.
    public init(countLimit: Int = 500, totalCostLimit: Int = 20 * 1024 * 1024) {
        storage.countLimit = countLimit
        storage.totalCostLimit = totalCostLimit
    }

    /// Returns the cached body for `url`, joins a load already in flight, or starts `load`.
    public func data(for url: URL, load: @escaping @Sendable () async throws -> Data) async throws -> Data {
        if let cached = storage.object(forKey: url as NSURL) {
            return cached as Data
        }

        let task: Task<Data, any Error>
        if var running = inFlight[url], !running.task.isCancelled {
            running.callers += 1
            inFlight[url] = running
            task = running.task
        } else {
            // The new task inherits the caller's priority, which the HTTP client uses to order requests.
            task = Task { try await load() }
            inFlight[url] = Load(task: task, callers: 1)
        }
        defer {
            if inFlight[url]?.task == task { inFlight[url] = nil }
        }

        let data = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { await self.callerCancelled(url: url, task: task) }
        }
        storage.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        return data
    }

    /// Removes every cached response. Loads in flight are not affected.
    public func removeAll() {
        storage.removeAllObjects()
    }

    /// Number of callers waiting for the load of `url`. Used by tests.
    func callerCount(for url: URL) -> Int {
        inFlight[url]?.callers ?? 0
    }

    /// Cancels the load once none of its callers is waiting for it any more.
    private func callerCancelled(url: URL, task: Task<Data, any Error>) {
        guard var running = inFlight[url], running.task == task else { return }
        running.cancelledCallers += 1
        inFlight[url] = running
        if running.cancelledCallers >= running.callers {
            task.cancel()
        }
    }
}
