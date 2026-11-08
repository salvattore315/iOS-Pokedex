import Foundation

/// Describes a single API call. Each API defines its own endpoints by conforming to this protocol.
///
/// ```swift
/// struct UsersEndpoint: Endpoint {
///     let page: Int
///     var baseURL: URL { URL(string: "https://api.example.com/v1")! }
///     var path: String { "users" }
///     var queryItems: [URLQueryItem] { [.init(name: "page", value: "\(page)")] }
/// }
/// ```
public protocol Endpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: Data? { get }
}

public extension Endpoint {
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }
    var body: Data? { nil }

    /// Builds the `URLRequest` for this endpoint.
    /// - Throws: ``APIError/invalidURL`` if the components do not form a valid URL.
    func makeRequest(timeout: TimeInterval = 30) throws(APIError) -> URLRequest {
        let url = path.isEmpty ? baseURL : baseURL.appending(path: path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw .invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let finalURL = components.url else { throw .invalidURL }

        var request = URLRequest(url: finalURL, timeoutInterval: timeout)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}

/// An endpoint built from an absolute URL, for APIs that return full links
/// (for example a `next` page link in a paginated response).
public struct URLEndpoint: Endpoint {
    public let baseURL: URL
    public var path: String { "" }

    public init(_ url: URL) {
        self.baseURL = url
    }
}
