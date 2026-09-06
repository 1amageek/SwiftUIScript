import SwiftUI
import SwiftUIScriptGallery
import WidgetKit

@main
struct PreviewWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScriptWidgetPreview(supportedFamily: .systemSmall)
    }
}
