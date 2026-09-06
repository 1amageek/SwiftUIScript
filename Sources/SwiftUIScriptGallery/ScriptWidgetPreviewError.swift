import Foundation

enum ScriptWidgetPreviewError: Error, LocalizedError {
    case unprepared

    var errorDescription: String? {
        switch self {
        case .unprepared:
            "Preview timeline did not prepare a SwiftUIScript view."
        }
    }
}
