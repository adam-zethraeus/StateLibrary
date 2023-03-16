import TreeState

// MARK: - TreeValueAccess

@TreeActor
protocol TreeValueAccess {
  var treeValue: TreeValue? { get nonmutating set }
}

// MARK: - TreeValue

@TreeActor
struct TreeValue {
  let runtime: Runtime
  let id: FieldID
  var scope: AnyScope? {
    try? runtime.getScope(for: id.nodeID)
  }

  func getValue<T: TreeState>(as t: T.Type) -> T? {
    runtime.getValue(field: id, as: t)
  }

  func setValue(to newValue: some TreeState) {
    runtime.setValue(field: id, to: newValue)
  }
}

// MARK: - ValueField

protocol ValueField<WrappedValue> {
  associatedtype WrappedValue: TreeState
  var access: any TreeValueAccess { get }
  var anyInitial: any TreeState { get }
  var initial: WrappedValue { get }
}

// MARK: - Value

@propertyWrapper
public struct Value<WrappedValue: TreeState>: ValueField, Accessor {

  // MARK: Lifecycle

  public init(wrappedValue: WrappedValue) {
    self.initial = wrappedValue
    self.inner = .init(initialValue: wrappedValue)
  }

  // MARK: Public

  @TreeActor public var wrappedValue: WrappedValue {
    get {
      let value = inner
        .treeValue?
        .getValue(as: WrappedValue.self) ?? inner.cache
      return value
    }
    nonmutating set {
      inner.cache = newValue
      inner
        .treeValue?
        .setValue(to: newValue)
    }
  }

  public var projectedValue: Projection<WrappedValue> {
    .init(
      self,
      initial: initial
    )
  }

  // MARK: Internal

  @TreeActor final class InnerValue: TreeValueAccess {

    // MARK: Lifecycle

    init(initialValue: WrappedValue) {
      self.cache = initialValue
    }

    // MARK: Internal

    var treeValue: TreeValue?
    var cache: WrappedValue
  }

  let inner: InnerValue

  let initial: WrappedValue

  var value: WrappedValue {
    get {
      wrappedValue
    }
    nonmutating set {
      wrappedValue = newValue
    }
  }

  var source: ProjectionSource {
    if let id = inner.treeValue?.id {
      .valueField(id)
    } else {
      .programmatic
    }
  }

  var access: any TreeValueAccess { inner }
  var anyInitial: any TreeState {
    initial
  }

  func isValid() -> Bool {
    inner.treeValue != nil
  }

}
