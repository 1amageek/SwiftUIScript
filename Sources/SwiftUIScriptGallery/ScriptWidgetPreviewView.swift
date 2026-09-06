import SwiftUI

struct ScriptWidgetPreviewView: View {
    let entry: ScriptWidgetPreviewEntry

    var body: some View {
        Group {
            switch entry.content {
            case .success(let view):
                view
            case .failure(let error):
                ContentUnavailableView {
                    Label("SwiftUIScript preview failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(String(describing: error))
                }
            }
        }
        .containerBackground(for: .widget) {
            entry.background
        }
    }
}
