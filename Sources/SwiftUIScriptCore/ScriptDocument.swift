import Foundation

/// An immutable compiled SwiftUIScript document.
public struct ScriptDocument: Codable, Equatable, Sendable {
    public static let formatVersion = 1

    public let formatVersion: Int
    public let root: ScriptNode

    public init(root: ScriptNode, formatVersion: Int = ScriptDocument.formatVersion) {
        self.formatVersion = formatVersion
        self.root = root
    }
}
