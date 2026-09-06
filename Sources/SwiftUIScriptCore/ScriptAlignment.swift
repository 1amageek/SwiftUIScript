import Foundation

public enum ScriptAlignment: String, Equatable, Sendable {
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

public enum ScriptVerticalAlignment: String, Equatable, Sendable {
    case top
    case center
    case bottom
    case firstTextBaseline
    case lastTextBaseline
}

public enum ScriptEdge: String, Equatable, Sendable {
    case all
    case horizontal
    case vertical
    case top
    case leading
    case bottom
    case trailing
}

public enum ScriptTextAlignment: String, Equatable, Sendable {
    case leading
    case center
    case trailing
}
