import Disposable
import Foundation
import TreeState

// MARK: - NodeID

/// The runtime identifier  representing a ``Node``.
///
/// String serialised `NodeIDs` are formatted as `<UUID>:<CUID>`
public struct NodeID: TreeState, LosslessStringConvertible {

  // MARK: Lifecycle

  /// Create a `NodeID` from its `String` serialised representation:`<UUID>:<CUID>`
  public init?(_ description: String) {
    let components = description
      .split(
        maxSplits: 1,
        omittingEmptySubsequences: false,
        whereSeparator: { $0 == ":" }
      )
    guard components.count == 2
    else {
      return nil
    }
    guard let uuid = UUID(uuidString: String(components[0]))
    else {
      return nil
    }
    self.uuid = uuid
    self.cuid = CUID(String(components[1]))
  }

  init(uuid: UUID = Self.makeUUID(), cuid: CUID? = nil) {
    self.uuid = uuid
    self.cuid = cuid
  }

  /// Decode a `NodeID` from a serialised representation.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let str = try container.decode(String.self)
    guard let nodeID = NodeID(str)
    else {
      throw NodeIDDecodingError()
    }
    self = nodeID
  }

  // MARK: Public

  /// The `String` serialised representation of a NodeID following the format
  /// `"<UUID>:<OptionalMetadata>"`
  public var description: String {
    "\(uuid.description):\(cuid?.description ?? "")"
  }

  /// Encode a `NodeID` to a serialised representation.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }

  #if DEBUG
  public static func incrementForTesting() -> AnyDisposable {
    incrementingForTesting = 1
    return .init {
      incrementingForTesting = nil
    }
  }

  private static var incrementingForTesting: Int?

  private static func makeUUID() -> UUID {
    if let num = Self.incrementingForTesting {
      Self.incrementingForTesting = num + 1
      return UUID.num(num)
    } else {
      return UUID()
    }
  }
  #else
  private static func makeUUID() -> UUID { UUID() }
  #endif
  // MARK: Internal

  /// A custom invalid `NodeID` which should never be present in serialised output.
  static let invalid = NodeID(uuid: .min, cuid: .invalid)

  /// A custom `NodeID` indicating a reference to the StateTree system itself.
  static let system = NodeID(uuid: .min, cuid: .system)

  /// A custom `NodeID` identifying the root node.
  static let root = NodeID(uuid: .max, cuid: .root)

  let uuid: UUID
  let cuid: CUID?

}

// MARK: - NodeIDDecodingError

class NodeIDDecodingError: Error { }

extension UUID {

  /// An invalid `UUID`
  fileprivate static var min: UUID {
    UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
  }

  /// A `UUID` used to build the custom ``NodeID`` values representing the
  /// root node and its lack of routing parent.
  fileprivate static var max: UUID {
    UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
  }

  #if DEBUG
  /// A custom incrementing UUID value used only in testing
  fileprivate static func num(_ num: Int) -> UUID {
    let numStr = String(num)
    let padded = String(repeating: "0", count: 12 - numStr.count) + numStr
    return UUID(
      uuidString: "F0000000-F000-F000-F000-\(padded)"
    ) ?? UUID(
      uuidString: "F0000000-F000-F000-F000-FFFFFFFFFFFF"
    )!
  }
  #endif
}
