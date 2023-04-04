@_spi(Implementation) import Behaviors
import Disposable
import Emitter
import Utilities

// MARK: - RunBehavior

public struct RunBehavior<Input>: Rules {

  // MARK: Lifecycle

  public init<B: SyncBehaviorType>(_ behavior: B, input: Input, handler: B.Handler)
    where B.Input == Input
  {
    self.startable = (input, StartableBehavior<Input>(behavior: behavior, handler: handler))
  }

  public init<Output>(
    moduleFile: String = #file,
    line: Int = #line,
    column: Int = #column,
    id: BehaviorID? = nil,
    subscribe: @escaping Behaviors.Make<Void, Output>.AsyncFunc.NonThrowing,
    onSuccess _: @escaping @TreeActor (_ value: Output) -> Void
  ) where Input == Void {
    let id = id ?? .meta(
      moduleFile: moduleFile,
      line: line,
      column: column,
      meta: "rule-async-nothrow"
    )
    let behavior = Behaviors.make(
      id,
      input: Void.self,
      subscribe: subscribe
    )
    self.startable = ((), StartableBehavior<Void>(
      behavior: behavior
    ))
  }

  public init<Output>(
    _ moduleFile: String = #file,
    _ line: Int = #line,
    _ column: Int = #column,
    id: BehaviorID? = nil,
    subscribe: @escaping Behaviors.Make<Void, Output>.AsyncFunc.Throwing,
    onResult _: @escaping @TreeActor (_ result: Result<Output, any Error>) -> Void
  ) where Input == Void {
    let behavior = Behaviors.make(
      id ?? .meta(moduleFile: moduleFile, line: line, column: column, meta: "rule-async-throws"),
      input: Void.self,
      subscribe: subscribe
    )
    self.startable = ((), StartableBehavior<Void>(
      behavior: behavior
    ))
  }

  public init<Seq: AsyncSequence>(
    _ moduleFile: String = #file,
    _ line: Int = #line,
    _ column: Int = #column,
    id: BehaviorID? = nil,
    behavior: @escaping () async -> Seq,
    onValue: @escaping @TreeActor (_ value: Seq.Element) -> Void,
    onFinish: @escaping @TreeActor () -> Void,
    onFailure: @escaping @TreeActor (_ error: Error) -> Void
  ) where Input == Void {
    let behavior = Behaviors.make(
      id ?? .meta(moduleFile: moduleFile, line: line, column: column, meta: "rule-stream"),
      input: Void.self,
      subscribe: behavior
    )
    self.startable = ((), StartableBehavior<Void>(
      behavior: behavior,
      handler: .init(onValue: onValue, onFinish: onFinish, onFailure: onFailure, onCancel: { })
    ))
  }

  init<Value>(
    _ moduleFile: String = #file,
    _ line: Int = #line,
    _ column: Int = #column,
    id: BehaviorID? = nil,
    behavior: @escaping () async -> some Emitting<Value>,
    onValue: @escaping @TreeActor (_ value: Value) -> Void,
    onFinish: @escaping @TreeActor () -> Void,
    onFailure: @escaping @TreeActor (_ error: Error) -> Void
  ) where Input == Void {
    self.init(
      moduleFile,
      line,
      column,
      id: id,
      behavior: { await behavior().values },
      onValue: onValue,
      onFinish: onFinish,
      onFailure: onFailure
    )
  }

  // MARK: Public

  public func act(
    for lifecycle: RuleLifecycle,
    with context: RuleContext
  )
    -> LifecycleResult
  {
    let (input, behavior) = startable
    switch lifecycle {
    case .didStart:
      let (_, finalizer) = behavior.start(
        manager: context.runtime.behaviorManager,
        input: input,
        scope: context.scope
      )
      if let finalizer {
        let disposable = Disposables.Task.detached {
          await finalizer()
        } onDispose: { }
        context.scope.own(disposable)
      }
    case .didUpdate:
      break
    case .willStop:
      break
    case .handleIntent:
      break
    }
    return .init()
  }

  public mutating func applyRule(with _: RuleContext) throws { }

  public mutating func removeRule(with _: RuleContext) throws { }

  public mutating func updateRule(
    from _: RunBehavior,
    with _: RuleContext
  ) throws { }

  // MARK: Internal

  let startable: (input: Input, behavior: StartableBehavior<Input>)

}

#if canImport(Combine)
import Combine
extension RunBehavior {
  /// Make an unbounded async-safe publisher -> async -> Behavior bridge.
  ///
  /// This initializer creates an intermediate subscription on a single actor before re-emitting
  /// its values for concurrent consumption.
  /// Publishers like `PassthroughSubject` and `CurrentValueSubject` whose
  /// emissions are not all sent from the same actor will drop values when bridged with `.values`.
  public init<Element>(
    _ moduleFile: String = #file,
    _ line: Int = #line,
    _ column: Int = #column,
    id: BehaviorID? = nil,
    behavior: @escaping () async -> some Publisher<Element, any Error>,
    onValue: @escaping @TreeActor (_ value: Element) -> Void,
    onFinish: @escaping @TreeActor () -> Void,
    onFailure: @escaping @TreeActor (_ error: any Error) -> Void
  ) where Input == Void {
    self.init(
      moduleFile,
      line,
      column,
      id: id,
      behavior: {
        let publisher = await behavior()
        return Async.Combine.bridge(publisher: publisher)
      },
      onValue: onValue,
      onFinish: onFinish,
      onFailure: onFailure
    )
  }

  /// Make an unbounded async-safe publisher -> async -> Behavior bridge.
  ///
  /// This initializer creates an intermediate subscription on a single actor before re-emitting
  /// its values for concurrent consumption.
  /// Publishers like `PassthroughSubject` and `CurrentValueSubject` whose
  /// emissions are not all sent from the same actor will drop values when bridged with `.values`.
  public init<Element>(
    _ moduleFile: String = #file,
    _ line: Int = #line,
    _ column: Int = #column,
    id: BehaviorID? = nil,
    behavior: @escaping () async -> some Publisher<Element, Never>,
    onValue: @escaping @TreeActor (_ value: Element) -> Void,
    onFinish: @escaping @TreeActor () -> Void,
    onFailure: @escaping @TreeActor (_ error: any Error) -> Void
  ) where Input == Void {
    self.init(
      moduleFile,
      line,
      column,
      id: id,
      behavior: {
        let publisher = await behavior()
        return Async.Combine.bridge(publisher: publisher.setFailureType(to: Error.self))
      },
      onValue: onValue,
      onFinish: onFinish,
      onFailure: onFailure
    )
  }
}
#endif