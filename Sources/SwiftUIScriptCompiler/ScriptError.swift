import Foundation

public struct ScriptSourceLocation: Equatable, Sendable {
    public let utf8Offset: Int

    public init(utf8Offset: Int) {
        self.utf8Offset = utf8Offset
    }
}

public enum ScriptError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptySource
    case sourceTooLarge(limit: Int)
    case parseRecovery(location: ScriptSourceLocation)
    case unsupportedSyntax(name: String, location: ScriptSourceLocation)
    case unsupportedConstructor(name: String, location: ScriptSourceLocation)
    case unsupportedModifier(name: String, location: ScriptSourceLocation)
    case unsupportedArgumentLabel(label: String, API: String, location: ScriptSourceLocation)
    case missingArgument(label: String, API: String, location: ScriptSourceLocation)
    case unknownIdentifier(name: String, location: ScriptSourceLocation)
    case invalidValue(reason: String, location: ScriptSourceLocation)
    case invalidRange(location: ScriptSourceLocation)
    case invalidModifierOrder(name: String, location: ScriptSourceLocation)
    case divisionByZero(location: ScriptSourceLocation)
    case nonFiniteResult(location: ScriptSourceLocation)
    case budgetExceeded(kind: String, limit: Int, location: ScriptSourceLocation)

    public var description: String {
        switch self {
        case .emptySource:
            return "SwiftUIScript source is empty."
        case .sourceTooLarge(let limit):
            return "SwiftUIScript source exceeds the " + String(limit) + "-byte limit."
        case .parseRecovery(let location):
            return "SwiftUIScript contains parser recovery at byte " + String(location.utf8Offset)
                + "."
        case .unsupportedSyntax(let name, let location):
            return "Unsupported syntax \(name) at byte \(location.utf8Offset)."
        case .unsupportedConstructor(let name, let location):
            return "Unsupported constructor \(name) at byte \(location.utf8Offset)."
        case .unsupportedModifier(let name, let location):
            return "Unsupported modifier \(name) at byte \(location.utf8Offset)."
        case .unsupportedArgumentLabel(let label, let API, let location):
            return "Unsupported argument label \(label) for \(API) at byte \(location.utf8Offset)."
        case .missingArgument(let label, let API, let location):
            return "Missing argument \(label) for \(API) at byte \(location.utf8Offset)."
        case .unknownIdentifier(let name, let location):
            return "Unknown identifier \(name) at byte \(location.utf8Offset)."
        case .invalidValue(let reason, let location):
            return "Invalid value at byte \(location.utf8Offset): \(reason)"
        case .invalidRange(let location):
            return "Invalid range at byte \(location.utf8Offset)."
        case .invalidModifierOrder(let name, let location):
            return "Modifier \(name) is not valid for this receiver at byte \(location.utf8Offset)."
        case .divisionByZero(let location):
            return "Division by zero at byte \(location.utf8Offset)."
        case .nonFiniteResult(let location):
            return "Non-finite arithmetic result at byte \(location.utf8Offset)."
        case .budgetExceeded(let kind, let limit, let location):
            return "SwiftUIScript " + kind + " budget " + String(limit) + " exceeded at byte "
                + String(location.utf8Offset) + "."
        }
    }
}
