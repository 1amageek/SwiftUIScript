import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

private struct RenderingPreview: Widget {
    struct Entry: TimelineEntry {
        let date: Date
        let content: Result<ScriptView, any Error>
    }

    struct Provider: TimelineProvider {
        enum Failure: Error {
            case previewContentRequired
        }

        func placeholder(in context: Context) -> Entry {
            Entry(date: .now, content: .failure(Failure.previewContentRequired))
        }

        func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
            completion(placeholder(in: context))
        }

        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
            completion(Timeline(entries: [placeholder(in: context)], policy: .never))
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SwiftUIScript.RenderingPreview", provider: Provider()) { entry in
            Group {
                switch entry.content {
                case .success(let view):
                    view
                case .failure(let error):
                    Text(String(describing: error))
                }
            }
            .containerBackground(.white, for: .widget)
        }
        .supportedFamilies([.systemLarge])
    }
}

#Preview("Native script rendering", as: .systemLarge) {
    RenderingPreview()
} timeline: {
    let source = #"""
    VStack(alignment: .leading, spacing: 20) {
        Text("SwiftUIScript").font(.system(size: 24, weight: .bold))
        Text("Rendered by WidgetKit").font(.system(size: 14))
            .foregroundStyle(Color.gray)
        HStack(spacing: 16) {
            Image(systemName: "photo.fill").resizable().scaledToFit()
                .frame(width: 48, height: 48).foregroundStyle(Color.blue)
            VStack(alignment: .leading, spacing: 6) {
                Text("Native images").font(.system(size: 17, weight: .semibold))
                Text("Text, images and layout").font(.system(size: 13))
            }
        }
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12).fill(Color.blue)
                .frame(width: 76, height: 48)
            Circle().fill(Color.orange).frame(width: 48, height: 48)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40)).foregroundStyle(Color.green)
        }
    }.foregroundStyle(Color.black)
    """#
    let content = Result(catching: { try ScriptView(ScriptCompiler().compile(source)) })
    RenderingPreview.Entry(date: .now, content: content)
}
