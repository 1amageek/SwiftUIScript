import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

#Preview("Quick note · static sample", as: .systemSmall) {
    ScriptWidgetPreview(supportedFamily: .systemSmall)
} timeline: {
    let source = #"""
    VStack(alignment: .leading, spacing: 10) {
        Text("Quick note").font(.system(size: 14, weight: .medium))
        Text("Leave room for the unexpected.")
            .font(.system(size: 20, weight: .regular, design: .serif))
            .foregroundStyle(Color(hex: "#454C41"))
            .lineLimit(3)
        Text("Draft · This session").font(.system(size: 10))
            .foregroundStyle(Color(hex: "#958A38"))
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color(hex: "#FFF4AE"))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    """#
    let document = Result(catching: { try ScriptCompiler().compile(source) })
    let content = document.flatMap { document in
        Result(catching: { try ScriptView(document) })
    }
    ScriptWidgetPreviewEntry(date: .now, content: content, background: .white)
}
