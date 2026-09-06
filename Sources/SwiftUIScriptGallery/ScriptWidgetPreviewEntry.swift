import SwiftUI
import SwiftUIScript
import WidgetKit

struct ScriptWidgetPreviewEntry: TimelineEntry {
    let date: Date
    let content: Result<ScriptView, any Error>
    let background: Color

    init(
        date: Date,
        content: Result<ScriptView, any Error>,
        background: Color = .clear
    ) {
        self.date = date
        self.content = content
        self.background = background
    }

    static func unprepared(date: Date = .now) -> Self {
        Self(date: date, content: .failure(ScriptWidgetPreviewError.unprepared))
    }
}
