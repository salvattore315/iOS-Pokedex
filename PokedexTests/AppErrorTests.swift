import Testing
import Networking
@testable import Pokedex

struct AppErrorTests {
    @Test func mapsAPIErrors() {
        #expect(AppError(.offline) == .offline)
        #expect(AppError(.timeout) == .offline)
        #expect(AppError(.http(statusCode: 404)) == .notFound)
        #expect(AppError(.http(statusCode: 503)) == .server)
        #expect(AppError(.http(statusCode: 429)) == .server)
        #expect(AppError(.http(statusCode: 400)) == .unexpected)
        #expect(AppError(.cancelled) == .unexpected)
    }

    @Test func notFoundIsNotRetryable() {
        #expect(!AppError.notFound.isRetryable)
        #expect(AppError.offline.isRetryable)
    }

    @Test func viewStateExposesValue() {
        let state: ViewState<Int> = .loaded(3)
        #expect(state.value == 3)
        #expect(ViewState<Int>.loading.isLoading)
        #expect(ViewState<Int>.failed(.offline) == .failed(.offline))
    }
}
