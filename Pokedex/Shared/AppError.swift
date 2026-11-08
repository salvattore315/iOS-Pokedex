import Foundation
import Networking

/// Errors the screens know how to show. Built from ``APIError`` by the service layer.
enum AppError: Error, Equatable, Sendable {
    case offline
    case notFound
    case server
    case unexpected

    init(_ error: APIError) {
        switch error {
        case .offline, .timeout:
            self = .offline
        case .http(let code) where code == 404:
            self = .notFound
        case .http(let code) where code >= 500 || code == 429:
            self = .server
        default:
            self = .unexpected
        }
    }

    var title: String {
        switch self {
        case .offline: String(localized: "error.offline.title", defaultValue: "No connection")
        case .notFound: String(localized: "error.notFound.title", defaultValue: "Not found")
        case .server: String(localized: "error.server.title", defaultValue: "Server unavailable")
        case .unexpected: String(localized: "error.unexpected.title", defaultValue: "Something went wrong")
        }
    }

    var message: String {
        switch self {
        case .offline: String(localized: "error.offline.message", defaultValue: "Check your connection and try again.")
        case .notFound: String(localized: "error.notFound.message", defaultValue: "This Pokémon could not be found.")
        case .server: String(localized: "error.server.message", defaultValue: "PokéAPI is not responding. Try again in a moment.")
        case .unexpected: String(localized: "error.unexpected.message", defaultValue: "Please try again.")
        }
    }

    /// Whether the screen should offer a "Retry" button.
    var isRetryable: Bool { self != .notFound }
}
