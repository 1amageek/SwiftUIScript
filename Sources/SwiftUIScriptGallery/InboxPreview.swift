import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

#Preview("Inbox · static sample", as: .systemMedium) {
    ScriptWidgetPreview(supportedFamily: .systemMedium)
} timeline: {
    let source = #"""
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 7) {
            Text("Inbox").font(.system(size: 17, weight: .medium))
            Text("2 unread").font(.system(size: 11))
                .foregroundStyle(Color(hex: "#999F95"))
            Spacer()
            Image(systemName: "magnifyingglass").font(.system(size: 13))
                .foregroundStyle(Color(hex: "#ABB0A8"))
        }
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color(hex: "#54A9C4"))
                .frame(width: 6, height: 6).padding(.top, 5)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Research agent").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("2:40 PM").font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#A5AAA0"))
                }
                Text("Three Bay Area stories, with key details ready to explore.")
                    .font(.system(size: 12)).foregroundStyle(Color(hex: "#939B8E"))
                    .lineLimit(2)
            }
        }
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color(hex: "#54A9C4"))
                .frame(width: 6, height: 6).padding(.top, 5)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Motion agent").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("2:32 PM").font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#A5AAA0"))
                }
                Text("Content comes and goes independently.")
                    .font(.system(size: 12)).foregroundStyle(Color(hex: "#939B8E"))
                    .lineLimit(2)
            }
        }
    }
    """#
    let document = Result(catching: { try ScriptCompiler().compile(source) })
    let content = document.flatMap { document in
        Result(catching: { try ScriptView(document) })
    }
    ScriptWidgetPreviewEntry(date: .now, content: content, background: .white)
}
