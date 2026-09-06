import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import WidgetKit

#Preview("Location · static sample", as: .systemLarge) {
    ScriptWidgetPreview(supportedFamily: .systemLarge)
} timeline: {
    let images: [String: Image] = [
        "bodegamap": Image("BodegaMap", bundle: .module),
        "bodeganorthwest": Image("BodegaNorthWest", bundle: .module),
        "bodeganortheast": Image("BodegaNorthEast", bundle: .module),
        "bodegasoutheast": Image("BodegaSouthEast", bundle: .module),
    ]
    let source = #"""
    ZStack(alignment: .bottomLeading) {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image(asset: "bodeganorthwest").resizable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Image(asset: "bodeganortheast").resizable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 0) {
                Image(asset: "bodegamap").resizable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Image(asset: "bodegasoutheast").resizable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        LinearGradient(colors: [Color.clear, Color(hex: "#F5FBF8")], startPoint: .top, endPoint: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        VStack(alignment: .leading, spacing: 6) {
            Text("Bodega Bay").font(.system(size: 20, weight: .medium))
            Text("California, United States").font(.system(size: 13))
                .foregroundStyle(Color(hex: "#7B9186"))
            Text("© OpenStreetMap contributors").font(.system(size: 9))
                .foregroundStyle(Color(hex: "#718579"))
        }
        .padding(18)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    """#
    let document = Result(catching: { try ScriptCompiler().compile(source) })
    let content = document.flatMap { document in
        Result(catching: { try ScriptView(document, images: images) })
    }
    ScriptWidgetPreviewEntry(
        date: .now,
        content: content,
        background: Color(red: 0.95, green: 0.98, blue: 0.96)
    )
}
