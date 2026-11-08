import Foundation

/// Errors produced by the networking layer, already classified so the app can react to them.
public enum APIError: Error, Sendable {
    /// The endpoint could not be turned into a valid URL.
    case invalidURL
    /// There is no internet connection.
    case offline
    /// The request took too long.
    case timeout
    /// The task was cancelled (for example, the view disappeared).
    case cancelled
    /// The server answered with a non-2xx status code.
    case http(statusCode: Int)
    /// The response body could not be decoded. Keeps the original `DecodingError` for debugging.
    case decoding(any Error & Sendable)
    /// Any other transport failure. Keeps the original `URLError`.
    case transport(URLError)

    /// `true` for 404, so callers can show a "not found" state instead of a generic error.
    public var isNotFound: Bool {
        if case .http(404) = self { true } else { false }
    }

    /// `true` when trying again may succeed.
    public var isRetryable: Bool {
        switch self {
        case .offline, .timeout: true
        case .http(let code): code >= 500 || code == 429
        default: false
        }
    }
}

extension APIError: Equatable {
    /// Compares by case. For `decoding`, the underlying errors are compared by their description,
    /// since `Error` itself is not `Equatable`.
    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL), (.offline, .offline), (.timeout, .timeout), (.cancelled, .cancelled):
            true
        case let (.http(a), .http(b)):
            a == b
        case let (.decoding(a), .decoding(b)):
            String(describing: a) == String(describing: b)
        case let (.transport(a), .transport(b)):
            a == b
        default:
            false
        }
    }
}

extension APIError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .invalidURL: "Invalid URL"
        case .offline: "Offline"
        case .timeout: "Timed out"
        case .cancelled: "Cancelled"
        case .http(let code): "HTTP \(code)"
        case .decoding(let error): "Decoding failed: \(error)"
        case .transport(let error): "Transport error: \(error.code.rawValue) \(error.localizedDescription)"
        }
    }
}

extension APIError {
    /// Maps a `URLError` to the matching ``APIError`` case.
    init(_ error: URLError) {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            self = .offline
        case .timedOut:
            self = .timeout
        case .cancelled:
            self = .cancelled
        case .badURL, .unsupportedURL:
            self = .invalidURL
        default:
            self = .transport(error)
        }
    }
}
