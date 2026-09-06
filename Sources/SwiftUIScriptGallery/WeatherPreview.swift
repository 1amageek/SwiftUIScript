import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

#Preview("Weather · static sample", as: .systemMedium) {
    ScriptWidgetPreview(supportedFamily: .systemMedium)
} timeline: {
    let source = #"""
    VStack(alignment: .leading, spacing: 6) {
        Text("Bodega Bay").font(.system(size: 15, weight: .medium))
        HStack(alignment: .bottom) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("58°").font(.system(size: 42, weight: .thin))
                Text("F").font(.system(size: 10))
            }
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "sun.max").font(.system(size: 20, weight: .light))
                Text("Clear").font(.system(size: 10))
            }
            .padding(.bottom, 8)
        }
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Sat")
                Image(systemName: "sun.max.fill")
                Text("63°")
            }.frame(width: 54)
            VStack(spacing: 4) {
                Text("Sun")
                Image(systemName: "sun.max.fill")
                Text("65°")
            }.frame(width: 54)
            VStack(spacing: 4) {
                Text("Mon")
                Image(systemName: "cloud.sun.fill")
                Text("72°")
            }.frame(width: 54)
            VStack(spacing: 4) {
                Text("Tue")
                Image(systemName: "sun.max.fill")
                Text("70°")
            }.frame(width: 54)
            VStack(spacing: 4) {
                Text("Wed")
                Image(systemName: "cloud.sun.fill")
                Text("66°")
            }.frame(width: 54)
        }
        .font(.system(size: 10))
    }
    .foregroundStyle(Color.white)
    """#
    let document = Result(catching: { try ScriptCompiler().compile(source) })
    let content = document.flatMap { document in
        Result(catching: { try ScriptView(document) })
    }
    ScriptWidgetPreviewEntry(
        date: .now,
        content: content,
        background: Color(red: 0.43, green: 0.61, blue: 0.75)
    )
}
