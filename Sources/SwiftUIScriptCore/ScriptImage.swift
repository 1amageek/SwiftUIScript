import Foundation

public enum ScriptImage: Codable, Equatable, Sendable {
    case systemName(String)
    case asset(String)
}
