import UIKit
import Networking

/// Loads images through the app's ``HTTPClient`` and keeps the decoded result in memory.
///
/// Going through the client instead of `AsyncImage` gives images what the API calls already have:
/// the dedicated session with its TCP fallback after an HTTP/3 stall, the shared disk cache,
/// the request limiter (ordered by task priority) and deduplication of requests in flight.
///
/// Cancelling the calling task cancels the request once nobody else is waiting for it, so a card
/// that scrolls off screen stops using the network.
final class ImageLoader: Sendable {
    private let client: any HTTPClient
    /// `NSCache` is thread-safe, but the SDK does not mark it `Sendable`.
    nonisolated(unsafe) private let cache = NSCache<NSURL, UIImage>()

    /// - Parameters:
    ///   - client: Performs the requests. The app passes the same client the API uses.
    ///   - countLimit: Maximum number of decoded images kept in memory.
    ///   - totalCostLimit: Maximum total size of the decoded images, in bytes.
    init(client: any HTTPClient, countLimit: Int = 300, totalCostLimit: Int = 150 * 1024 * 1024) {
        self.client = client
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    /// The image for `url` if it is already in memory. Synchronous, so a view can show it on its first frame.
    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Returns the image for `url`, from memory or from the client.
    ///
    /// The request runs with the priority of the calling task.
    /// - Throws: The client's ``APIError``; ``APIError/decoding(_:)`` if the body is not an image;
    ///   ``APIError/cancelled`` if the calling task was cancelled.
    func image(for url: URL) async throws(APIError) -> UIImage {
        if let cached = cachedImage(for: url) { return cached }

        let data = try await client.data(for: ImageEndpoint(url: url))
        guard let image = UIImage(data: data) else {
            throw .decoding(ImageDecodingError(url: url))
        }
        // Decodes the bitmap here, off the main thread, instead of on the first draw.
        let prepared = await image.byPreparingForDisplay() ?? image
        cache.setObject(prepared, forKey: url as NSURL, cost: prepared.memoryCost)
        guard !Task.isCancelled else { throw .cancelled }
        return prepared
    }

    /// Removes every image from memory.
    func removeAll() {
        cache.removeAllObjects()
    }
}

/// The body of a successful response could not be read as an image.
struct ImageDecodingError: Error, Sendable {
    let url: URL
}

/// A GET for an absolute image URL.
struct ImageEndpoint: Endpoint {
    let url: URL

    var baseURL: URL { url }
    var path: String { "" }
    var headers: [String: String] { ["Accept": "image/*"] }
}

private extension UIImage {
    /// Approximate size of the decoded bitmap, in bytes.
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
