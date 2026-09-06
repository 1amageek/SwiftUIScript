import Foundation

public struct ScriptLinearGradient: Codable, Equatable, Sendable {
    public let colors: [ScriptColor]
    public let startPoint: ScriptUnitPoint
    public let endPoint: ScriptUnitPoint

    public init(
        colors: [ScriptColor],
        startPoint: ScriptUnitPoint,
        endPoint: ScriptUnitPoint
    ) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
}

public enum ScriptUnitPoint: String, Codable, Equatable, Sendable {
    case topLeading
    case top
    case topTrailing
    case leading
    case center
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing
}
