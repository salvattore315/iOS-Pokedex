/// The state every screen renders. Covers the design's loading, empty and error screens.
enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(AppError)

    var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }

    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }
}

extension ViewState: Equatable where Value: Equatable {}
extension ViewState: Sendable where Value: Sendable {}
