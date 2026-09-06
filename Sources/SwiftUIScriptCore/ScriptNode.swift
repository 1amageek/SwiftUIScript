import Foundation

/// A typed node in the portable presentation tree.
public struct ScriptNode: Equatable, Sendable {
    public let kind: ScriptNodeKind
    public let modifiers: [ScriptModifier]

    public init(kind: ScriptNodeKind, modifiers: [ScriptModifier] = []) {
        self.kind = kind
        self.modifiers = modifiers
    }

    public func applying(_ modifier: ScriptModifier) -> ScriptNode {
        ScriptNode(kind: kind, modifiers: modifiers + [modifier])
    }
}

public indirect enum ScriptNodeKind: Equatable, Sendable {
    case text(String)
    case label(text: String, systemImage: String)
    case image(ScriptImage)
    case vStack(alignment: ScriptAlignment, spacing: Double?, children: [ScriptNode])
    case hStack(alignment: ScriptVerticalAlignment, spacing: Double?, children: [ScriptNode])
    case zStack(alignment: ScriptAlignment, children: [ScriptNode])
    case spacer(minLength: Double?)
    case divider
    case shape(ScriptShape)
    case color(ScriptColor)
    case linearGradient(ScriptLinearGradient)
}
