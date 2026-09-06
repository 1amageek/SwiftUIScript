import Foundation

public enum ScriptShape: Codable, Equatable, Sendable {
    case rectangle
    case roundedRectangle(cornerRadius: Double)
    case circle
    case ellipse
    case capsule
}
