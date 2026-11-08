import Foundation

/// In-memory cache for response bodies that also deduplicates requests in flight.
///
/// - Completed responses are kept in an `NSCache`, which evicts entries under memory pressure.
/// - While a URL is loading, other callers asking for the same URL await the same task
///   instead of starting a second request.
/// - Failed loads are never cached, so the next call tries again.
public actor ResponseCache {
    private let storage = NSCache<NSURL, NSData>()
    private var inFlight: [URL: Task<Data, any Error>] = [:]

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
        if let running = inFlight[url] {
            return try await running.value
        }

        let task = Task { try await load() }
        inFlight[url] = task
        defer { inFlight[url] = nil }

        let data = try await task.value
        storage.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        return data
    }

    /// Removes every cached response. Loads in flight are not affected.
    public func removeAll() {
        storage.removeAllObjects()
    }
}
