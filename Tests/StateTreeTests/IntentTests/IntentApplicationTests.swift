import Disposable
import StateTree
import XCTest

// MARK: - IntentApplicationTests

final class IntentApplicationTests: XCTestCase {

  let stage = DisposableStage()

  override func setUp() { }
  override func tearDown() {
    stage.reset()
  }

  @TreeActor
  func test_singleStep_intentApplication() async throws {
    let tree = Tree(root: ValueSetNode())
    await tree.run(on: stage)

    // No value since intent has not triggered.
    XCTAssertNil(try tree.rootNode.value)
    XCTAssertNil(try tree.info.pendingIntent)
    // make the intent
    let intent = try XCTUnwrap(
      Intent(
        ValueSetStep(value: 123)
      )
    )
    // signal the intent
    try tree.signal(intent: intent)
    // intent has been applied
    XCTAssertEqual(try tree.rootNode.value, 123)
    // and the intent is finished
    XCTAssertNil(try tree.info.pendingIntent)
  }

  @TreeActor
  func test_decodedPayloadStep_intentApplication() async throws {
    let tree = Tree(root: PrivateIntentNode())
    await tree.run(on: stage)

    // No value is present since the intent has not triggered.
    XCTAssertNil(try tree.rootNode.payload)
    XCTAssertNil(try tree.info.pendingIntent)
    // make the intent
    let intent = try XCTUnwrap(
      Intent(
        // `PrivateStep(payload:)` is private. We can't directly instantiate it.
        // PrivateStep(payload: "SOMETHING"),

        // However we can construct a matching step with applicable values
        // using a decodable payload passed to the 'Step' helper.

        // We would usually use a model extracted from a deeplink or equivalent.
        // Here we use the dictionary-init helper.
        Step(name: "private-step", fields: ["payload": "PAYLOAD"])
      )
    )
    // signal the intent
    try tree.signal(intent: intent)
    // intent has been applied
    XCTAssertEqual(try tree.rootNode.payload, "PAYLOAD")
    // and the intent is finished
    XCTAssertNil(try tree.info.pendingIntent)
  }

  @TreeActor
  func test_multiStep_intentApplication() async throws {
    let tree = Tree(root: RoutingIntentNode<ValueSetNode>())
    await tree.run(on: stage)

    // No routed node since intent has not triggered.
    XCTAssertNil(try tree.rootNode.child)
    XCTAssertNil(try tree.info.pendingIntent)
    // make the intent
    let intent = try XCTUnwrap(
      Intent(
        RouteTriggerStep(shouldRoute: true),
        ValueSetStep(value: 321)
      )
    )
    // signal the intent
    try tree.signal(intent: intent)
    // intent has been applied
    XCTAssertNotNil(try tree.rootNode.child)
    XCTAssertEqual(try tree.rootNode.child?.value, 321)
    // and the intent is finished
    XCTAssertNil(try tree.info.pendingIntent)
  }

  @TreeActor
  func test_nodeSkippingIntentApplication() async throws {
    let tree = Tree(root: RoutingIntentNode<IntermediateNode<ValueSetNode>>())
    await tree.run(on: stage)

    // No routed node since intent has not triggered.
    XCTAssertNil(try tree.rootNode.child)
    XCTAssertNil(try tree.info.pendingIntent)
    // make the intent
    let intent = try XCTUnwrap(
      Intent(
        // Handled by RoutingIntentNode
        RouteTriggerStep(shouldRoute: true),

        // IntermediateNode has no intent handlers

        // Handled by ValueSetNode
        ValueSetStep(value: 321)
      )
    )
    // signal the intent
    try tree.signal(intent: intent)
    // intent has been applied
    XCTAssertNotNil(try tree.rootNode.child)
    XCTAssertEqual(try tree.rootNode.child?.child?.value, 321)
    // and the intent is finished
    XCTAssertNil(try tree.info.pendingIntent)
  }

  @TreeActor
  func test_singleNodeRepeatedStep_intentApplication() async throws {
    let tree = Tree(root: RepeatStepNode())
    await tree.run(on: stage)

    // No value since intent has not triggered.
    XCTAssertNil(try tree.rootNode.value1)
    XCTAssertNil(try tree.rootNode.value2)
    XCTAssertNil(try tree.info.pendingIntent)
    // make the intent
    let intent = try XCTUnwrap(
      Intent(
        RepeatStep1(value: "stepOne"),
        RepeatStep2(value: "stepTwo")
      )
    )
    // signal the intent
    try tree.signal(intent: intent)
    // intent has been applied
    XCTAssertEqual(try tree.rootNode.value1, "stepOne")
    XCTAssertEqual(try tree.rootNode.value2, "stepTwo")
    // and the intent is finished
    XCTAssertNil(try tree.info.pendingIntent)
  }

  @TreeActor
  func test_pendingStep_intentApplication() async throws {
    let tree = Tree(root: PendingNode<ValueSetNode>())
    await tree.run(on: stage)

    // The node's values start as false, preventing routing
    XCTAssertEqual(try tree.rootNode.shouldRoute, false)
    XCTAssertEqual(try tree.rootNode.mayRoute, false)
    XCTAssertNil(try tree.rootNode.child)
    // there is no active intent
    XCTAssertNil(try tree.info.pendingIntent)

    // make the intent
    let intent = try XCTUnwrap(
      Intent(
        PendingNodeStep(shouldRoute: true)
      )
    )
    // signal the intent
    try tree.signal(intent: intent)

    // intent has not been fully applied and is still active
    XCTAssertEqual(try tree.rootNode.shouldRoute, false)
    XCTAssertNil(try tree.rootNode.child)
    XCTAssertNotNil(try tree.info.pendingIntent)

    try tree.rootNode.mayRoute = true

    // once the state changes, the intent applies and finishes
    XCTAssertEqual(try tree.rootNode.shouldRoute, true)
    XCTAssertNotNil(try tree.rootNode.child)
    XCTAssertNil(try tree.info.pendingIntent)
  }

  @TreeActor
  func test_maybeInvalidatedIntent() async throws {
    try await runTest(shouldInvalidate: false)
    stage.reset()
    try await runTest(shouldInvalidate: true)

    func runTest(shouldInvalidate: Bool) async throws {
      let tree = Tree(root: InvalidatingNode<PendingNode<ValueSetNode>>())
      await tree.run(on: stage)

      // The node's values start false preventing routing
      XCTAssertEqual(try tree.rootNode.shouldRoute, false)
      XCTAssertEqual(try tree.rootNode.validNext, .initial)
      XCTAssertNil(try tree.rootNode.initialNext)
      XCTAssertNil(try tree.rootNode.laterNext)
      // there is no active intent
      XCTAssertNil(try tree.info.pendingIntent)

      // make the intent
      let intent = try XCTUnwrap(
        Intent(
          MaybeInvalidatedStep(shouldRoute: true),
          PendingNodeStep(shouldRoute: true),
          ValueSetStep(value: 111)
        )
      )
      // signal the intent
      try tree.signal(intent: intent)

      // the first intent applies triggering a route to 'initialNext'
      XCTAssertEqual(try tree.rootNode.shouldRoute, true)
      XCTAssertNotNil(try tree.rootNode.initialNext)
      // (the other route to the same node type remains disabled due to the 'validNext' state)
      XCTAssertEqual(try tree.rootNode.validNext, .initial)
      XCTAssertNil(try tree.rootNode.laterNext)
      // but the unrelated 'mayRoute' state prevents routing
      XCTAssertEqual(try tree.rootNode.initialNext?.mayRoute, false)
      // the second intent step can not yet apply
      XCTAssertEqual(try tree.rootNode.initialNext?.shouldRoute, false)
      // and so neither can the third
      XCTAssertNil(try tree.rootNode.initialNext?.child?.value)
      // the intent remains active as its step is pending
      XCTAssertNotNil(try tree.info.pendingIntent)

      if shouldInvalidate {
        let initialChildType = type(of: try tree.rootNode.initialNext)

        // 'mayRoute' keeps the second step pending, while root node's state changes
        try tree.rootNode.validNext = .later

        // the root's initial child has deallocated and and a new identically typed child is routed
        XCTAssertNil(try tree.rootNode.initialNext)
        XCTAssertNotNil(try tree.rootNode.laterNext)
        let laterChildType = type(of: try tree.rootNode.laterNext)
        XCTAssertEqual("\(initialChildType)", "\(laterChildType)")

        // but the intent has finished
        XCTAssertNil(try tree.info.pendingIntent)
        // and the second and third steps never execute on the new node
        XCTAssertEqual(try tree.rootNode.laterNext?.shouldRoute, false)

        // (even if the state blocking the previous node is changed in the new one)
        try tree.rootNode.initialNext?.mayRoute = true
        XCTAssertEqual(try tree.rootNode.laterNext?.shouldRoute, false)

      } else {
        // a change to the blocking mayRoute releases the second step from pending and allow
        // the third to execute and the intent to finish
        try tree.rootNode.initialNext?.mayRoute = true
        XCTAssertNotNil(try tree.rootNode.initialNext?.child)
        XCTAssertEqual(try tree.rootNode.initialNext?.child?.value, 111)
        XCTAssertNil(try tree.info.pendingIntent)
      }
    }
  }

}

// MARK: - DefaultInitNode

/// Helper allowing this test file to instantiate generic node.
private protocol DefaultInitNode: Node {
  init()
}

/// Intent definitions
extension IntentApplicationTests {

  fileprivate struct RepeatStep1: IntentStep {
    static let name = "repeat-1"
    let value: String
  }

  fileprivate struct RepeatStep2: IntentStep {
    static let name = "repeat-2"
    let value: String
  }

  fileprivate struct ValueSetStep: IntentStep {
    static let name = "value-set-step"
    let value: Int
  }

  fileprivate struct RouteTriggerStep: IntentStep {
    static let name = "route-trigger-step"
    let shouldRoute: Bool
  }

  fileprivate struct PendingNodeStep: IntentStep {
    static let name = "pending-step"
    let shouldRoute: Bool
  }

  fileprivate struct MaybeInvalidatedStep: IntentStep {
    static let name = "maybe-invalid"
    let shouldRoute: Bool
  }

  fileprivate struct PrivateStep: IntentStep {
    private init(payload _: String) { fatalError() }
    static let name = "private-step"
    let payload: String
  }

}

/// Test Node definitions
extension IntentApplicationTests {

  fileprivate struct ValueSetNode: DefaultInitNode {

    @Value var value: Int?

    var rules: some Rules {
      OnIntent(ValueSetStep.self) { step in
        .resolution {
          value = step.value
        }
      }
    }
  }

  fileprivate struct PrivateIntentNode: DefaultInitNode {
    @Value var payload: String?
    var rules: some Rules {
      OnIntent(PrivateStep.self) { step in
        .resolution {
          payload = step.payload
        }
      }
    }
  }

  fileprivate struct RepeatStepNode: DefaultInitNode {

    @Value var value1: String?
    @Value var value2: String?
    var rules: some Rules {
      OnIntent(RepeatStep1.self) { step in
        .resolution {
          value1 = step.value
        }
      }
      OnIntent(RepeatStep2.self) { step in
        .resolution {
          value2 = step.value
        }
      }
    }
  }

  fileprivate struct RoutingIntentNode<Next: DefaultInitNode>: DefaultInitNode {
    @Route(Next.self) var child
    @Value private var shouldRoute: Bool = false
    var rules: some Rules {
      if shouldRoute {
        $child.route(to: Next())
      }
      OnIntent(RouteTriggerStep.self) { step in
        .resolution {
          shouldRoute = step.shouldRoute
        }
      }
    }
  }

  fileprivate struct IntermediateNode<Next: DefaultInitNode>: DefaultInitNode {
    @Route(Next.self) var child
    var rules: some Rules {
      $child.route(to: Next())
    }
  }

  fileprivate struct PendingNode<Next: DefaultInitNode>: DefaultInitNode {

    @Value var mayRoute: Bool = false
    @Value var shouldRoute: Bool = false
    @Route(Next.self) var child

    var rules: some Rules {
      if shouldRoute {
        $child.route(to: Next())
      }
      OnIntent(PendingNodeStep.self) { step in
        mayRoute
          ? .resolution { shouldRoute = step.shouldRoute }
          : .pending
      }
    }
  }

  fileprivate struct InvalidatingNode<Next: DefaultInitNode>: DefaultInitNode {
    @Route(Next.self) var initialNext
    @Route(Next.self) var laterNext
    @Value var validNext: ValidNext = .initial
    @Value var shouldRoute: Bool = false

    enum ValidNext: TreeState {
      case initial
      case later
    }

    var rules: some Rules {
      if shouldRoute {
        switch validNext {
        case .initial: $initialNext.route(to: Next())
        case .later: $laterNext.route(to: Next())
        }
      }
      OnIntent(MaybeInvalidatedStep.self) { step in
        .resolution {
          shouldRoute = step.shouldRoute
        }
      }
    }

  }

}
