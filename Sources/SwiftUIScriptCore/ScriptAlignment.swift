import Foundation

public enum ScriptAlignment: String, Codable, Equatable, Sendable {
    case leading
    case center
    case trailing
    case top
    case bottom
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

public enum ScriptVerticalAlignment: String, Codable, Equatable, Sendable {
    case top
    case center
    case bottom
    case firstTextBaseline
    case lastTextBaseline
}

public enum ScriptEdge: String, Codable, Equatable, Sendable {
    case all
    case horizontal
    case vertical
    case top
    case leading
    case bottom
    case trailing
}

public enum ScriptTextAlignment: String, Codable, Equatable, Sendable {
    case leading
    case center
    case trailing
}
