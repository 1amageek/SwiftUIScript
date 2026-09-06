import Foundation

public enum ScriptShape: Equatable, Sendable {
    case rectangle
    case roundedRectangle(cornerRadius: Double)
    case circle
    case ellipse
    case capsule
}
