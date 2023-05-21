import Disposable
import TreeActor

// MARK: - Attach
public struct Attach<Router: RouterType>: Rules {

  // MARK: Lifecycle

  public init(
    router: Router,
    to route: Route<Router>
  ) {
    self.route = route
    self.router = router
  }

  // MARK: Public

  public func act(for _: RuleLifecycle, with _: RuleContext) -> LifecycleResult {
    .init()
  }

  public mutating func applyRule(with _: RuleContext) throws {
    route.appliedRouter = router
  }

  public mutating func removeRule(with _: RuleContext) throws {
    route.appliedRouter = nil
  }

  public mutating func updateRule(
    from new: Self,
    with _: RuleContext
  ) throws {
    router = new.router
    route.appliedRouter?.update(from: new.router)
  }

  // MARK: Internal

  var router: Router
  let route: Route<Router>

}
