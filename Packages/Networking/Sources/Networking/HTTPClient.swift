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

/// ``HTTPClient`` backed by `URLSession` and async/await.
public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let timeout: TimeInterval
    private let makeDecoder: @Sendable () -> JSONDecoder

    /// - Parameters:
    ///   - session: The session used to perform requests. Inject a custom one in tests.
    ///   - timeout: Request timeout in seconds.
    ///   - makeDecoder: Builds the decoder for each response. Defaults to snake_case keys.
    public init(
        session: URLSession = .shared,
        timeout: TimeInterval = 30,
        makeDecoder: @escaping @Sendable () -> JSONDecoder = URLSessionHTTPClient.defaultDecoder
    ) {
        self.session = session
        self.timeout = timeout
        self.makeDecoder = makeDecoder
    }

    public func data(for endpoint: some Endpoint) async throws(APIError) -> Data {
        let request = try endpoint.makeRequest(timeout: timeout)
        return try await perform(request)
    }

    public func send<T: Decodable & Sendable>(_ endpoint: some Endpoint, as type: T.Type) async throws(APIError) -> T {
        let data = try await data(for: endpoint)
        do {
            return try makeDecoder().decode(T.self, from: data)
        } catch {
            throw .decoding(error)
        }
    }

    /// Performs the request and validates the status code.
    func perform(_ request: URLRequest) async throws(APIError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
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
