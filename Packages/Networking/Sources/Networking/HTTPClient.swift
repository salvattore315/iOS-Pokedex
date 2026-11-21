import Foundation
import os

/// Sends requests described by an ``Endpoint`` and returns raw data or decoded values.
///
/// All failures are reported as ``APIError`` thanks to typed throws, so callers
/// can switch over every case without a generic `catch`.
public protocol HTTPClient: Sendable {
    /// Returns the response body of a successful (2xx) request.
    func data(for endpoint: some Endpoint) async throws(APIError) -> Data

    /// Decodes the response body of a successful (2xx) request into `type`.
    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint, as type: T.Type) async throws(APIError) -> T
}

public extension HTTPClient {
    /// Decodes the response body, inferring the type from the call site.
    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws(APIError) -> T {
        try await send(endpoint, as: T.self)
    }
}

/// ``HTTPClient`` backed by `URLSession` and async/await, with optional caching of GET responses
/// and an optional cap on concurrent requests.
///
/// The priority of the calling task is passed on: it orders requests waiting in the ``RequestLimiter``
/// and sets the priority of the underlying `URLSessionTask`.
///
/// Some networks drop QUIC packets once the handshake is done. With HTTP/3 every request to a host shares
/// that connection, so all of them hang until they time out, and a new QUIC connection stalls the same way.
/// After the first request that times out or loses its connection, the client switches to a fallback
/// session that only speaks TCP (HTTP/2) for the rest of its life, and sends a GET once more on it.
public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let fallbackSession: URLSession?
    /// `true` once a request has stalled on `session`. From then on every request uses `fallbackSession`.
    private let hasStalled = OSAllocatedUnfairLock(initialState: false)
    private let cache: ResponseCache?
    private let limiter: RequestLimiter?
    private let timeout: TimeInterval
    private let makeDecoder: @Sendable () -> JSONDecoder

    /// - Parameters:
    ///   - session: The session used to perform requests. Defaults to ``makeSession(urlCache:)``.
    ///     Inject a custom one in tests.
    ///   - fallbackSession: Used after a stall on `session`. Defaults to ``makeFallbackSession(urlCache:)``.
    ///     Pass `nil` to keep retrying on `session`.
    ///   - cache: Optional cache for GET responses. Pass `nil` to always hit the network.
    ///   - limiter: Optional cap on concurrent requests. Pass `nil` for no cap.
    ///   - timeout: Request timeout in seconds. Short enough that a stalled request can be retried
    ///     before the user gives up.
    ///   - makeDecoder: Builds the decoder for each response. Defaults to snake_case keys.
    public init(
        session: URLSession = URLSessionHTTPClient.makeSession(),
        fallbackSession: URLSession? = URLSessionHTTPClient.makeFallbackSession(),
        cache: ResponseCache? = nil,
        limiter: RequestLimiter? = nil,
        timeout: TimeInterval = URLSessionHTTPClient.defaultTimeout,
        makeDecoder: @escaping @Sendable () -> JSONDecoder = URLSessionHTTPClient.defaultDecoder
    ) {
        self.session = session
        self.fallbackSession = fallbackSession
        self.cache = cache
        self.limiter = limiter
        self.timeout = timeout
        self.makeDecoder = makeDecoder
    }

    public func data(for endpoint: some Endpoint) async throws(APIError) -> Data {
        let request = try endpoint.makeRequest(timeout: timeout)
        guard let cache, endpoint.method == .get, let url = request.url else {
            return try await perform(request)
        }
        do {
            return try await cache.data(for: url) { try await self.perform(request) }
        } catch let error as APIError {
            throw error
        } catch {
            throw .transport(URLError(.unknown))
        }
    }

    public func send<T: Decodable & Sendable>(_ endpoint: some Endpoint, as type: T.Type) async throws(APIError) -> T {
        let data = try await data(for: endpoint)
        do {
            return try makeDecoder().decode(T.self, from: data)
        } catch {
            throw .decoding(error)
        }
    }

    /// Waits for a slot in the limiter, if any, then performs the request.
    func perform(_ request: URLRequest) async throws(APIError) -> Data {
        guard let limiter else { return try await load(request) }
        do {
            try await limiter.acquire()
        } catch {
            throw .cancelled
        }
        let result: Result<Data, APIError>
        do {
            result = .success(try await load(request))
        } catch {
            result = .failure(error)
        }
        await limiter.release()
        return try result.get()
    }

    /// Sends the request, switching to the fallback session and retrying a GET once if the connection stalled.
    private func load(_ request: URLRequest) async throws(APIError) -> Data {
        let isIdempotent = request.httpMethod == HTTPMethod.get.rawValue
        do {
            return try await loadOnce(request, on: currentSession)
        } catch let error as URLError where Self.isStall(error) {
            hasStalled.withLock { $0 = true }
            guard isIdempotent else { throw APIError(error) }
            do {
                return try await loadOnce(request, on: currentSession)
            } catch {
                throw Self.apiError(from: error)
            }
        } catch {
            throw Self.apiError(from: error)
        }
    }

    /// The session new requests should use.
    var currentSession: URLSession {
        guard let fallbackSession, hasStalled.withLock({ $0 }) else { return session }
        return fallbackSession
    }

    /// `true` for failures a fresh connection may fix.
    static func isStall(_ error: URLError) -> Bool {
        error.code == .timedOut || error.code == .networkConnectionLost
    }

    /// Sends the request and validates the status code. Transport failures are thrown as `URLError`
    /// so ``load(_:)`` can tell a stall from other errors; anything else is already an ``APIError``.
    private func loadOnce(_ request: URLRequest, on session: URLSession) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request, delegate: TaskPriorityDelegate(Task.currentPriority))
        } catch is CancellationError {
            throw APIError.cancelled
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(statusCode: http.statusCode)
        }
        return data
    }

    private static func apiError(from error: any Error) -> APIError {
        switch error {
        case let error as APIError: error
        case let error as URLError: APIError(error)
        case is CancellationError: .cancelled
        default: .transport(URLError(.unknown))
        }
    }

    /// A decoder that maps `snake_case` JSON keys to `camelCase` properties.
    @Sendable public static func defaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

// MARK: - Session

public extension URLSessionHTTPClient {
    /// Default request timeout, in seconds.
    static let defaultTimeout: TimeInterval = 15

    /// The configuration behind ``makeSession(urlCache:)``, spelled out instead of relying on `URLSession.shared`.
    ///
    /// - Parameter urlCache: Disk cache for HTTP responses. Defaults to `URLCache.shared`, which the app sizes at launch.
    static func makeConfiguration(urlCache: URLCache = .shared) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = defaultTimeout
        // Gives up on a request (retry included) instead of waiting minutes for the network.
        configuration.timeoutIntervalForResource = 60
        // Fail fast when offline so the screen can offer a retry.
        configuration.waitsForConnectivity = false
        // Matches the app's RequestLimiter, so HTTP/1.1 and HTTP/2 fallbacks never queue behind each other.
        configuration.httpMaximumConnectionsPerHost = 4
        return configuration
    }

    /// A dedicated session built from ``makeConfiguration(urlCache:)``.
    static func makeSession(urlCache: URLCache = .shared) -> URLSession {
        URLSession(configuration: makeConfiguration(urlCache: urlCache))
    }

    /// ``makeConfiguration(urlCache:)`` limited to TLS 1.2, which keeps the session on TCP.
    ///
    /// `URLSession` has no public switch to turn HTTP/3 off, and `assumesHTTP3Capable = false` does not stop it
    /// once the server has advertised `Alt-Svc: h3`. QUIC requires TLS 1.3, so capping TLS at 1.2 is what makes
    /// the session fall back to HTTP/2 over TCP. TLS 1.2 still meets App Transport Security.
    static func makeFallbackConfiguration(urlCache: URLCache = .shared) -> URLSessionConfiguration {
        let configuration = makeConfiguration(urlCache: urlCache)
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv12
        return configuration
    }

    /// A TCP-only session built from ``makeFallbackConfiguration(urlCache:)``.
    static func makeFallbackSession(urlCache: URLCache = .shared) -> URLSession {
        URLSession(configuration: makeFallbackConfiguration(urlCache: urlCache))
    }
}

/// Gives each `URLSessionTask` the priority of the Swift task that started it.
private final class TaskPriorityDelegate: NSObject, URLSessionTaskDelegate {
    private let priority: Float

    init(_ priority: TaskPriority) {
        self.priority = if priority >= .userInitiated {
            URLSessionTask.highPriority
        } else if priority <= .utility {
            URLSessionTask.lowPriority
        } else {
            URLSessionTask.defaultPriority
        }
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        task.priority = priority
    }
}
