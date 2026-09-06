import SwiftUI
import WidgetKit

public struct ScriptWidgetPreview: Widget {
    private let supportedFamily: WidgetFamily

    public init() {
        supportedFamily = .systemSmall
    }

    public init(supportedFamily: WidgetFamily) {
        self.supportedFamily = supportedFamily
    }

    public var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "SwiftUIScript.Preview",
            provider: ScriptWidgetPreviewProvider()
        ) { entry in
            ScriptWidgetPreviewView(entry: entry)
        }
        .configurationDisplayName("SwiftUIScript Preview")
        .description("Preview-only native WidgetKit rendering.")
        .supportedFamilies([supportedFamily])
    }
}
