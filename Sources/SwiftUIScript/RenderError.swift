/// Host composition failures detected before a presentation is rendered.
public enum RenderError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case missingImage(String)
    case invalidReceiver
}
