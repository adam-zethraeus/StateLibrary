import Disposable
import SwiftUI
import TreeActor
import XCTest
@_spi(Implementation) @testable import StateTree
@_spi(Implementation) @testable import StateTreeCallbacks

// MARK: - EventTests

@TreeActor
final class EventTests: XCTestCase {

  func test_startStop() async throws {
    let tree = Tree(root: Parent())
    let handle = try tree.start()
    @Reported(handle.root) var root
    var rootDidStopCount = 0
    $root.onStop(subscriber: self) {
      rootDidStopCount += 1
    }
    XCTAssertEqual(rootDidStopCount, 0)
    try tree.stop()
    XCTAssertEqual(rootDidStopCount, 1)
  }

  func test_update() async throws {
    let tree = Tree(root: Parent())
    let handle = try tree.start()
    @Reported(handle.root) var root
    var rootFireCount = 0
    $root.onChange(subscriber: self) {
      rootFireCount += 1
    }
    XCTAssert(rootFireCount == 0)
    root.v1 = 1
    XCTAssertEqual(rootFireCount, 1)
    root.v1 = 3
    XCTAssertEqual(rootFireCount, 2)
  }

  func test_childUpdates() async throws {
    let tree = Tree(root: Parent())
    let handle = try tree.start()
    @Reported(handle.root) var root

    var emitCount = 0

    if let single = $root.$single {
      single.onChange(subscriber: self) {
        emitCount += 1
      }
    }

    $root.$union2.b?.onChange(subscriber: self) {
      emitCount += 1
    }

    $root.$union3.c?.onChange(subscriber: self) {
      emitCount += 1
    }

    for node in $root.$list {
      node.onChange(subscriber: self) {
        emitCount += 1
      }
    }

    XCTAssertEqual(emitCount, 0)

    let count = 3 + $root.$list.count

    root.v1 = 1

    XCTAssertEqual(emitCount, count)

    root.v1 = 3

    XCTAssertEqual(emitCount, count * 2)
  }
}

extension EventTests {

  struct ChildOne: Node {
    @Projection var v1: Int
    var rules: some Rules { () }
  }

  struct ChildTwo: Node, Identifiable {
    let id: Int
    @Projection var v1: Int
    var rules: some Rules { () }
  }

  struct ChildThree: Node {
    @Projection var v1: Int
    var rules: some Rules { () }
  }

  struct Parent: Node {
    @Value var v1: Int = 55
    @Route(ChildOne.self) var single
    @Route(ChildOne.self, ChildTwo.self) var union2
    @Route(ChildOne.self, ChildTwo.self, ChildThree.self) var union3
    @Route var list: [ChildTwo] = []

    var rules: some Rules {
      $single.route {
        ChildOne(v1: $v1)
      }
      $union2.route { .b(ChildTwo(id: 1, v1: $v1)) }
      $union3.route { .c(ChildThree(v1: $v1)) }

      $list.route {
        [
          .init(id: 1, v1: $v1),
          .init(id: 2, v1: $v1),
          .init(id: 3, v1: $v1),
          .init(id: 4, v1: $v1),
        ]
      }
    }
  }

}
