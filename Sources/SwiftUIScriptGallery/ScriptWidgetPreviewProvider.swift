import WidgetKit

struct ScriptWidgetPreviewProvider: TimelineProvider {
    typealias Entry = ScriptWidgetPreviewEntry

    func placeholder(in context: Context) -> Entry {
        .unprepared()
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(.unprepared())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [.unprepared()], policy: .never))
    }
}
