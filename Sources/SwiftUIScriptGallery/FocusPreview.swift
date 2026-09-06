import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

#Preview("Focus · static sample", as: .systemSmall) {
    ScriptWidgetPreview(supportedFamily: .systemSmall)
} timeline: {
    let source = #"""
        VStack(spacing: 8) {
            HStack {
                Text("Focus").font(.system(size: 14, weight: .medium))
            }
            ZStack {
                ForEach(0..<36) { tick in
                    Capsule().fill(Color(hex: "#667080"))
                        .frame(width: 2, height: 9)
                        .offset(x: 0, y: -42)
                        .rotationEffect(.degrees(tick * 10))
                }
                Circle().fill(Color(hex: "#B1B7C5"))
                    .frame(width: 42, height: 42).opacity(0.36)
                    .offset(x: 34, y: -22)
                Text("13:25").font(.system(size: 24, weight: .light))
                    .monospacedDigit().tracking(1)
            }
            .frame(width: 100, height: 100)
        }
        .foregroundStyle(Color(hex: "#F6F7FB"))
        """#
    let document = Result(catching: { try ScriptCompiler().compile(source) })
    let content = document.flatMap { document in
        Result(catching: { try ScriptView(document) })
    }
    ScriptWidgetPreviewEntry(
        date: .now,
        content: content,
        background: Color(red: 0.08, green: 0.10, blue: 0.15)
    )
}
