import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

#Preview("Mood board · static sample", as: .systemLarge) {
    ScriptWidgetPreview(supportedFamily: .systemLarge)
} timeline: {
    let images: [String: Image] = [
        "architecture": Image("Architecture", bundle: .module),
        "coast": Image("Coast", bundle: .module),
        "flowers": Image("Flowers", bundle: .module),
        "mountains": Image("Mountains", bundle: .module),
    ]
    let source = #"""
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            Text("Collected moments").font(.system(size: 15, weight: .medium))
            Spacer()
            Image(systemName: "square.grid.2x2").font(.system(size: 12))
                .foregroundStyle(Color(hex: "#9BA293"))
        }
        HStack(spacing: 7) {
            VStack(spacing: 7) {
                Image(asset: "architecture").resizable().scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 100, idealHeight: 112, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                Image(asset: "coast").resizable().scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 70, idealHeight: 80, maxHeight: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            VStack(spacing: 7) {
                Image(asset: "flowers").resizable().scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 70, idealHeight: 80, maxHeight: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                Image(asset: "mountains").resizable().scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 100, idealHeight: 112, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity)
    """#
    let document = Result(catching: { try ScriptCompiler().compile(source) })
    let content = document.flatMap { document in
        Result(catching: { try ScriptView(document, images: images) })
    }
    ScriptWidgetPreviewEntry(date: .now, content: content, background: .white)
}
