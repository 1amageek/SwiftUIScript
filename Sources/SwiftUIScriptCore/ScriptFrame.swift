import Foundation

public enum ScriptDimension: Codable, Equatable, Sendable {
    case value(Double)
    case infinity
}

public enum ScriptFrame: Codable, Equatable, Sendable {
    case fixed(width: Double?, height: Double?, alignment: ScriptAlignment)
    case flexible(
        minWidth: ScriptDimension?,
        idealWidth: ScriptDimension?,
        maxWidth: ScriptDimension?,
        minHeight: ScriptDimension?,
        idealHeight: ScriptDimension?,
        maxHeight: ScriptDimension?,
        alignment: ScriptAlignment
    )
}
