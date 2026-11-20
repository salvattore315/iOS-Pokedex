import Foundation

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
public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let cache: ResponseCache?
    private let limiter: RequestLimiter?
    private let timeout: TimeInterval
    private let makeDecoder: @Sendable () -> JSONDecoder

    /// - Parameters:
    ///   - session: The session used to perform requests. Inject a custom one in tests.
    ///   - cache: Optional cache for GET responses. Pass `nil` to always hit the network.
    ///   - limiter: Optional cap on concurrent requests. Pass `nil` for no cap.
    ///   - timeout: Request timeout in seconds.
    ///   - makeDecoder: Builds the decoder for each response. Defaults to snake_case keys.
    public init(
        session: URLSession = .shared,
        cache: ResponseCache? = nil,
        limiter: RequestLimiter? = nil,
        timeout: TimeInterval = 30,
        makeDecoder: @escaping @Sendable () -> JSONDecoder = URLSessionHTTPClient.defaultDecoder
    ) {
        self.session = session
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

    /// Sends the request and validates the status code.
    private func load(_ request: URLRequest) async throws(APIError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request, delegate: TaskPriorityDelegate(Task.currentPriority))
        } catch let error as URLError {
            throw APIError(error)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .transport(URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else {
            throw .transport(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw .http(statusCode: http.statusCode)
        }
        return data
    }

    /// A decoder that maps `snake_case` JSON keys to `camelCase` properties.
    @Sendable public static func defaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
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
