// MARK: - AsyncValue

public actor AsyncThrowingValue<T: Sendable> {

  // MARK: Lifecycle

  public init() { }
  public init(value: T) {
    self._value = value
  }

  // MARK: Public

  public var value: T {
    get async throws {
      if let _value {
        _value
      } else {
        try await withCheckedThrowingContinuation { continuation in
          self.continuation = continuation
        }
      }
    }
  }

  public func resolve(_ value: T, act: @escaping () async -> Void = { }) async {
    await setFinal(value: value, act: act)
  }

  public func ifMatching(_ filter: (_ value: T?) -> Bool, run: @escaping () async -> Void) async {
    if filter(_value) {
      await run()
    }
  }

  // MARK: Private

  private var _value: T?
  private var continuation: CheckedContinuation<T, Error>?

  private func setFinal(value: T, act: () async -> Void = { }) async {
    guard _value == nil
    else {
      return
    }
    _value = value
    await act()
    continuation?.resume(with: .success(value))
  }

}