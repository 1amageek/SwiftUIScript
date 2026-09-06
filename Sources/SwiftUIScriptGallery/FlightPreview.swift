import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

#Preview("Flight · static sample", as: .systemMedium) {
    ScriptWidgetPreview(supportedFamily: .systemMedium)
} timeline: {
    let source = #"""
    VStack(alignment: .leading, spacing: 6) {
        Text("Flight").font(.system(size: 15, weight: .medium))
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("SFO").font(.system(size: 26, weight: .light))
                Text("San Francisco").font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#9BA099"))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("JFK").font(.system(size: 26, weight: .light))
                Text("New York").font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#9BA099"))
            }
        }
        ZStack(alignment: .leading) {
            Capsule().fill(Color(hex: "#EDF0EC")).frame(height: 4)
            Capsule().fill(Color(hex: "#58ADCB")).frame(width: 160, height: 4)
            Image(systemName: "airplane").font(.system(size: 16))
                .foregroundStyle(Color(hex: "#58ADCB"))
                .offset(x: 154, y: 0)
        }
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("09:40").font(.system(size: 16, weight: .medium))
                Text("Departure · PDT").font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#9BA099"))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("18:05").font(.system(size: 16, weight: .medium))
                Text("Arrival · EDT").font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#9BA099"))
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
