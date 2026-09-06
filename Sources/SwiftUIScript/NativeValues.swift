import SwiftUI
import SwiftUIScriptCore

extension ScriptDimension {
    var native: CGFloat {
        switch self {
        case .value(let value): value
        case .infinity: .infinity
        }
    }
}

extension ScriptColor {
    var native: Color {
        switch self {
        case .hex(let string):
            let digits = string.hasPrefix("#") ? String(string.dropFirst()) : string
            // Hex syntax is checked at compilation, before this native boundary.
            let value = UInt64(digits, radix: 16)!
            let shift = digits.count == 8 ? 8 : 0
            return Color(
                .sRGB,
                red: Double((value >> (16 + shift)) & 255) / 255,
                green: Double((value >> (8 + shift)) & 255) / 255,
                blue: Double((value >> shift) & 255) / 255,
                opacity: digits.count == 8 ? Double(value & 255) / 255 : 1
            )
        case .rgb(let red, let green, let blue, let opacity):
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
        case .named(let color):
            switch color {
            case .clear: return .clear
            case .black: return .black
            case .white: return .white
            case .gray: return .gray
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .mint: return .mint
            case .teal: return .teal
            case .cyan: return .cyan
            case .blue: return .blue
            case .indigo: return .indigo
            case .purple: return .purple
            case .pink: return .pink
            case .brown: return .brown
            case .primary: return .primary
            case .secondary: return .secondary
            }
        }
    }
}

extension ScriptShape {
    var native: AnyShape {
        switch self {
        case .rectangle: AnyShape(Rectangle())
        case .roundedRectangle(let radius): AnyShape(RoundedRectangle(cornerRadius: radius))
        case .circle: AnyShape(Circle())
        case .ellipse: AnyShape(Ellipse())
        case .capsule: AnyShape(Capsule())
        }
    }
}

extension ScriptFont {
    var native: Font {
        switch self {
        case .system(let size, let weight, let design):
            return .system(size: size, weight: weight?.native, design: design?.native)
        case .named(let name):
            switch name {
            case .largeTitle: return .largeTitle
            case .title: return .title
            case .title2: return .title2
            case .title3: return .title3
            case .headline: return .headline
            case .subheadline: return .subheadline
            case .body: return .body
            case .callout: return .callout
            case .footnote: return .footnote
            case .caption: return .caption
            case .caption2: return .caption2
            }
        }
    }
}

extension ScriptFontWeight {
    var native: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

extension ScriptFontDesign {
    var native: Font.Design {
        switch self {
        case .default: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

extension ScriptAlignment {
    var native: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        case .top: .top
        case .bottom: .bottom
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading, .topLeading, .bottomLeading: .leading
        case .trailing, .topTrailing, .bottomTrailing: .trailing
        case .center, .top, .bottom: .center
        }
    }
}

extension ScriptVerticalAlignment {
    var native: VerticalAlignment {
        switch self {
        case .top: .top
        case .center: .center
        case .bottom: .bottom
        case .firstTextBaseline: .firstTextBaseline
        case .lastTextBaseline: .lastTextBaseline
        }
    }
}

extension ScriptTextAlignment {
    var native: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

extension ScriptEdge {
    var native: Edge.Set {
        switch self {
        case .all: .all
        case .horizontal: .horizontal
        case .vertical: .vertical
        case .top: .top
        case .leading: .leading
        case .bottom: .bottom
        case .trailing: .trailing
        }
    }
}

extension ScriptUnitPoint {
    var native: UnitPoint {
        switch self {
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        }
    }
}

extension ScriptLinearGradient {
    var native: LinearGradient {
        LinearGradient(
            colors: colors.map(\.native), startPoint: startPoint.native, endPoint: endPoint.native)
    }
}
