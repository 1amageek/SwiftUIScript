import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

#Preview("News · static sample", as: .systemLarge) {
    ScriptWidgetPreview(supportedFamily: .systemLarge)
} timeline: {
    let images: [String: Image] = [
        "architecture": Image("Architecture", bundle: .module),
        "coast": Image("Coast", bundle: .module),
        "forest": Image("Forest", bundle: .module),
    ]
    let source = #"""
    VStack(alignment: .leading, spacing: 16) {
        HStack {
            Text("New stories").font(.system(size: 18, weight: .medium))
            Spacer()
            Text("TODAY").font(.system(size: 10, weight: .medium))
                .tracking(1.4).foregroundStyle(Color(hex: "#ABB0A8"))
        }
        HStack(spacing: 12) {
            Image(asset: "architecture").resizable().scaledToFill()
                .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                Text("A new language for spaces").font(.system(size: 14, weight: .medium))
                Text("Design · 4 min read").font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#A1A69E"))
            }
        }
        HStack(spacing: 12) {
            Image(asset: "coast").resizable().scaledToFill()
                .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                Text("The coast is calling").font(.system(size: 14, weight: .medium))
                Text("Travel · 6 min read").font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#A1A69E"))
            }
        }
        HStack(spacing: 12) {
            Image(asset: "forest").resizable().scaledToFill()
                .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                Text("Making room for the wild").font(.system(size: 14, weight: .medium))
                Text("Culture · 3 min read").font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#A1A69E"))
            }
        }
    }
    """#
    let document = Result(catching: { try ScriptCompiler().compile(source) })
    let content = document.flatMap { document in
        Result(catching: { try ScriptView(document, images: images) })
    }
    ScriptWidgetPreviewEntry(date: .now, content: content, background: .white)
}
