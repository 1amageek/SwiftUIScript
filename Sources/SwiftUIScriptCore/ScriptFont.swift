import Foundation

public enum ScriptFont: Equatable, Sendable {
    case named(ScriptNamedFont)
    case system(size: Double, weight: ScriptFontWeight?, design: ScriptFontDesign?)
}

public enum ScriptNamedFont: String, Equatable, Sendable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case callout
    case footnote
    case caption
    case caption2
}

public enum ScriptFontWeight: String, Equatable, Sendable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
}

public enum ScriptFontDesign: String, Equatable, Sendable {
    case `default`
    case rounded
    case serif
    case monospaced
}
