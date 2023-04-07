//import Disposable
//import Emitter
//import Foundation
//
//// MARK: - Tree
//
//@TreeActor
//public final class Tree_REMOVE {
//
//  // MARK: Lifecycle
//
//  public nonisolated init() { }
//
//  // MARK: Public
//
//  public nonisolated static let main: Tree_REMOVE = .init()
//
//  @_spi(Implementation) public var runtime: Runtime? {
//    _runtime
//  }
//
//  public var info: StateTreeInfo? { _runtime?.info }
//
//  // MARK: Private
//
//  private var _runtime: Runtime?
//
//}
//
//extension Tree_REMOVE {
//
//  // MARK: Public
//
//  @TreeActor
//  public func start<N: Node>(
//    root: N,
//    from initialState: TreeStateRecord? = nil,
//    dependencies: DependencyValues = .defaults,
//    configuration: RuntimeConfiguration = .init()
//  ) throws -> Tree<N> {
//    let runtime = Runtime(
//      tree: self,
//      dependencies: dependencies,
//      configuration: configuration
//    )
//
//    try setRuntime(runtime)
//
//    let scope = try runtime.start(
//      rootNode: root,
//      initialState: initialState
//    )
//
//    assert(runtime.isConsistent)
//    let disposable = AutoDisposable {
//      assert(runtime.isConsistent)
//      runtime.stop()
//      assert(runtime.isConsistent)
//      try? self.setRuntime(nil)
//      assert(runtime.isConsistent)
//    }
//    let lifetime = Tree(
//      runtime: runtime,
//      root: scope,
//      rootID: scope.nid,
//      disposable: disposable
//    )
//    return lifetime
//  }
//
//  // MARK: Internal
//
//  func setRuntime(_ runtime: Runtime?) throws {
//    if runtime != nil, _runtime != nil {
//      throw StartedTreeError()
//    }
//    _runtime = runtime
//  }
//
//}