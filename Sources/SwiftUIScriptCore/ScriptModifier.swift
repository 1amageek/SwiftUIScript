import Foundation

public indirect enum ScriptModifier: Equatable, Sendable {
    case font(ScriptFont)
    case foregroundStyle(ScriptColor)
    case frame(ScriptFrame)
    case padding(edge: ScriptEdge, amount: Double?)
    case background(ScriptBackground)
    case overlay(ScriptBackground)
    case clipShape(ScriptShape)
    case opacity(Double)
    case offset(x: Double, y: Double)
    case rotationEffect(degrees: Double)
    case shadow(color: ScriptColor, radius: Double, x: Double, y: Double)
    case lineLimit(Int)
    case multilineTextAlignment(ScriptTextAlignment)
    case tracking(Double)
    case monospacedDigit
    case resizable
    case scaledToFill
    case scaledToFit
    case fill(ScriptColor)
    case stroke(color: ScriptColor, lineWidth: Double)
}

public indirect enum ScriptBackground: Equatable, Sendable {
    case color(ScriptColor)
    case linearGradient(ScriptLinearGradient)
    case node(ScriptNode)
}
