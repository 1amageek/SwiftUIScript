import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

#Preview("Music · static sample", as: .systemMedium) {
    ScriptWidgetPreview(supportedFamily: .systemMedium)
} timeline: {
    let images: [String: Image] = [
        "flowers": Image("Flowers", bundle: .module),
    ]
    let source = #"""
    VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .center, spacing: 16) {
            Image(asset: "flowers")
                .resizable().scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 7) {
                Text("The Visit").font(.system(size: 18, weight: .medium))
                Text("Agar Agar").font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#939892"))
                HStack(spacing: 20) {
                    Image(systemName: "backward.end.fill").font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#A8ACA6"))
                    Image(systemName: "pause.fill").font(.system(size: 15))
                        .foregroundStyle(Color.white)
                        .frame(width: 38, height: 38)
                        .background(Color(hex: "#414740")).clipShape(Circle())
                    Image(systemName: "forward.end.fill").font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#A8ACA6"))
                }
            }
        }
        VStack(spacing: 8) {
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: "#ECEEEB")).frame(height: 4)
                Capsule().fill(Color(hex: "#858C82")).frame(width: 170, height: 4)
            }
            HStack {
                Text("2:26")
                Spacer()
                Text("−1:44")
            }
            .font(.system(size: 11)).foregroundStyle(Color(hex: "#8F958D"))
        }
    }
    """#
    let document = Result(catching: { try ScriptCompiler().compile(source) })
    let content = document.flatMap { document in
        Result(catching: { try ScriptView(document, images: images) })
    }
    ScriptWidgetPreviewEntry(date: .now, content: content, background: .white)
}
