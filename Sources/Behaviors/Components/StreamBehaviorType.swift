import Disposable
import TreeActor

// MARK: - StreamBehaviorType

public protocol StreamBehaviorType<Input, Output, Failure>: BehaviorType
  where Producer: AsyncSequence, Producer.Element == Output
{
  var subscriber: Behaviors.StreamSubscriber<Input, Output, Failure> { get }
  func start(
    input: Input,
    handler: Handler,
    resolving: Behaviors.Resolution
  ) async
    -> AnyDisposable
}

extension StreamBehaviorType {
  func scoped(
    to scope: some BehaviorScoping,
    manager: BehaviorManager,
    input: Input
  ) -> ScopedBehavior<Self> {
    .init(behavior: self, scope: scope, manager: manager, input: input)
  }

  func scoped(
    to scope: some BehaviorScoping,
    manager: BehaviorManager
  ) -> ScopedBehavior<Self> where Input == Void {
    .init(behavior: self, scope: scope, manager: manager, input: ())
  }

  func scoped(
    manager: BehaviorManager,
    input: Input
  ) -> (scope: some Disposable, behavior: ScopedBehavior<Self>) {
    let stage = BehaviorStage()
    return (stage, .init(behavior: self, scope: stage, manager: manager, input: input))
  }

  func scoped(manager: BehaviorManager)
    -> (scope: some Disposable, behavior: ScopedBehavior<Self>) where Input == Void
  {
    let stage = BehaviorStage()
    return (stage, .init(behavior: self, scope: stage, manager: manager, input: ()))
  }
}

// MARK: StreamBehaviorType.Func

extension StreamBehaviorType {
  typealias Func = (_ input: Input) async -> Producer
}