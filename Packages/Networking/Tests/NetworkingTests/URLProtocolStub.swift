import Foundation

/// Intercepts requests made by a `URLSession` and answers them with a stubbed response.
final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    nonisolated(unsafe) static var handler: Handler?
    static let requests = RequestLog()

    /// A session whose requests are all handled by this stub.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    /// Resets the handler and the request log between tests.
    static func reset(handler: @escaping Handler) {
        self.handler = handler
        requests.reset()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.record(request)
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Thread-safe record of the requests that reached the stub.
final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    var count: Int { lock.withLock { storage.count } }

    func record(_ request: URLRequest) { lock.withLock { storage.append(request) } }
    func reset() { lock.withLock { storage.removeAll() } }
}

extension HTTPURLResponse {
    static func stub(_ statusCode: Int, url: URL? = nil) -> HTTPURLResponse {
        HTTPURLResponse(url: url ?? URL(string: "https://api.example.com")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}
