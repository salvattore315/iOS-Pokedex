import Foundation
import Testing
import UIKit
import Networking
@testable import Pokedex

/// ``HTTPClient`` that answers every request with the same body and records what it was asked for.
/// With `waitsForCancellation`, each request hangs until its task is cancelled.
private final class ImageClientSpy: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private let body: Data
    private let waitsForCancellation: Bool
    private var _requests: [URLRequest] = []
    private var _priorities: [TaskPriority] = []
    private var _cancelledCount = 0

    init(body: Data, waitsForCancellation: Bool = false) {
        self.body = body
        self.waitsForCancellation = waitsForCancellation
    }

    var requests: [URLRequest] { lock.withLock { _requests } }
    var priorities: [TaskPriority] { lock.withLock { _priorities } }
    var cancelledCount: Int { lock.withLock { _cancelledCount } }

    func data(for endpoint: some Endpoint) async throws(APIError) -> Data {
        let request = try endpoint.makeRequest()
        lock.withLock {
            _requests.append(request)
            _priorities.append(Task.currentPriority)
        }
        if waitsForCancellation {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                lock.withLock { _cancelledCount += 1 }
                throw .cancelled
            }
        }
        return body
    }

    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint, as type: T.Type) async throws(APIError) -> T {
        throw .decoding(CocoaError(.featureUnsupported))
    }
}

struct ImageLoaderTests {
    private let url = URL(string: "https://example.com/artwork/1.png")!

    /// A 2×2 pixel PNG.
    private static let png: Data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: pixelFormat).pngData { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }

    private static var pixelFormat: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return format
    }

    @Test func loadsTheImageThroughTheClient() async throws {
        let client = ImageClientSpy(body: Self.png)
        let loader = ImageLoader(client: client)

        let image = try await loader.image(for: url)

        #expect(image.size == CGSize(width: 2, height: 2))
        #expect(client.requests.map(\.url) == [url])
        #expect(client.requests.first?.httpMethod == "GET")
        #expect(client.requests.first?.value(forHTTPHeaderField: "Accept") == "image/*")
    }

    @Test func servesLaterRequestsFromMemory() async throws {
        let client = ImageClientSpy(body: Self.png)
        let loader = ImageLoader(client: client)
        #expect(loader.cachedImage(for: url) == nil)

        let first = try await loader.image(for: url)
        let second = try await loader.image(for: url)

        #expect(first === second)
        #expect(loader.cachedImage(for: url) === first)
        #expect(client.requests.count == 1)
    }

    @Test func requestsAgainAfterTheCacheIsCleared() async throws {
        let client = ImageClientSpy(body: Self.png)
        let loader = ImageLoader(client: client)

        _ = try await loader.image(for: url)
        loader.removeAll()
        _ = try await loader.image(for: url)

        #expect(client.requests.count == 2)
    }

    @Test func cancellingTheCallerCancelsTheRequest() async throws {
        let client = ImageClientSpy(body: Self.png, waitsForCancellation: true)
        let loader = ImageLoader(client: client)
        let url = url

        let task = Task { try await loader.image(for: url) }
        while client.requests.isEmpty { await Task.yield() }
        task.cancel()

        await #expect(throws: APIError.self) { _ = try await task.value }
        #expect(client.cancelledCount == 1)
        #expect(loader.cachedImage(for: url) == nil)
    }

    @Test func passesTheCallerPriorityToTheClient() async throws {
        let client = ImageClientSpy(body: Self.png)
        let loader = ImageLoader(client: client)
        let url = url

        // Awaiting the task's value would escalate its priority, so wait for the request instead.
        let task = Task(priority: .utility) { try await loader.image(for: url) }
        while client.requests.isEmpty { await Task.yield() }

        #expect(client.priorities == [.utility])
        _ = try await task.value
    }

    @Test func failsWhenTheBodyIsNotAnImage() async {
        let client = ImageClientSpy(body: Data("not an image".utf8))
        let loader = ImageLoader(client: client)

        await #expect(throws: APIError.self) { _ = try await loader.image(for: url) }
        #expect(loader.cachedImage(for: url) == nil)
    }
}
