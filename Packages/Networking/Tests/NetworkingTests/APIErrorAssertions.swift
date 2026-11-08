import Foundation
@testable import Networking

/// Runs `operation` and returns the ``APIError`` it threw, or `nil` if it succeeded.
///
/// `APIError` is not `Equatable`, so tests match the returned value with `if case` / `switch`.
func caughtError(_ operation: () async throws(APIError) -> Void) async -> APIError? {
    do {
        try await operation()
        return nil
    } catch {
        return error
    }
}
