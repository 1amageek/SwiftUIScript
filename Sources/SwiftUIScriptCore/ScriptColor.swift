import Foundation

public enum ScriptColor: Codable, Equatable, Sendable {
    case hex(String)
    case rgb(red: Double, green: Double, blue: Double, opacity: Double)
    case named(ScriptNamedColor)
}

public enum ScriptNamedColor: String, Codable, Equatable, Sendable {
    case clear
    case black
    case white
    case gray
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown
    case primary
    case secondary
}
