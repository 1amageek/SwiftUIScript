import SwiftUI
import SwiftUIScriptCore

/// Renders a compiled presentation using native SwiftUI views and host-owned images.
public struct ScriptView: View {
    private let document: ScriptDocument
    private let images: [String: Image]

    public init(
        _ document: ScriptDocument,
        images: [String: Image] = [:]
    ) throws(RenderError) {
        guard document.formatVersion == ScriptDocument.formatVersion else {
            throw .unsupportedVersion(document.formatVersion)
        }
        try Self.validate(document.root, images: images)
        self.document = document
        self.images = images
    }

    public var body: some View {
        render(document.root)
    }

    private func render(_ node: ScriptNode) -> AnyView {
        var remaining = node.modifiers[...]
        let base: AnyView
        switch node.kind {
        case .text(let string):
            base = AnyView(Text(verbatim: string))
        case .label(let text, let systemImage):
            base = AnyView(Label(text, systemImage: systemImage))
        case .image(let source):
            let image: Image
            switch source {
            case .systemName(let name): image = Image(systemName: name)
            case .asset(let name):
                // The initializer verifies the complete immutable tree before rendering.
                image = images[name]!
            }
            if remaining.first == .resizable {
                base = AnyView(image.resizable())
                remaining = remaining.dropFirst()
            } else {
                base = AnyView(image)
            }
        case .vStack(let alignment, let spacing, let children):
            base = AnyView(
                VStack(alignment: alignment.horizontal, spacing: spacing.map { CGFloat($0) }) {
                    ForEach(children.indices, id: \.self) { render(children[$0]) }
                })
        case .hStack(let alignment, let spacing, let children):
            base = AnyView(
                HStack(alignment: alignment.native, spacing: spacing.map { CGFloat($0) }) {
                    ForEach(children.indices, id: \.self) { render(children[$0]) }
                })
        case .zStack(let alignment, let children):
            base = AnyView(
                ZStack(alignment: alignment.native) {
                    ForEach(children.indices, id: \.self) { render(children[$0]) }
                })
        case .spacer(let minLength):
            base = AnyView(Spacer(minLength: minLength.map { CGFloat($0) }))
        case .divider:
            base = AnyView(Divider())
        case .shape(let shape):
            switch remaining.first {
            case .fill(let color):
                base = AnyView(shape.native.fill(color.native))
                remaining = remaining.dropFirst()
            case .stroke(let color, let width):
                base = AnyView(shape.native.stroke(color.native, lineWidth: width))
                remaining = remaining.dropFirst()
            default:
                base = AnyView(shape.native)
            }
        case .color(let color):
            base = AnyView(color.native)
        case .linearGradient(let gradient):
            base = AnyView(gradient.native)
        }
        return remaining.reduce(base) { apply($1, to: $0) }
    }

    private func apply(_ modifier: ScriptModifier, to view: AnyView) -> AnyView {
        switch modifier {
        case .font(let font): return AnyView(view.font(font.native))
        case .foregroundStyle(let color): return AnyView(view.foregroundStyle(color.native))
        case .frame(let frame):
            switch frame {
            case .fixed(let width, let height, let alignment):
                return AnyView(
                    view.frame(
                        width: width.map { CGFloat($0) }, height: height.map { CGFloat($0) },
                        alignment: alignment.native
                    ))
            case .flexible(
                let minWidth, let idealWidth, let maxWidth,
                let minHeight, let idealHeight, let maxHeight, let alignment):
                return AnyView(
                    view.frame(
                        minWidth: minWidth?.native,
                        idealWidth: idealWidth?.native,
                        maxWidth: maxWidth?.native, minHeight: minHeight?.native,
                        idealHeight: idealHeight?.native, maxHeight: maxHeight?.native,
                        alignment: alignment.native
                    ))
            }
        case .padding(let edge, let amount):
            return AnyView(view.padding(edge.native, amount.map { CGFloat($0) }))
        case .background(let background): return AnyView(view.background(render(background)))
        case .overlay(let overlay): return AnyView(view.overlay(render(overlay)))
        case .clipShape(let shape): return AnyView(view.clipShape(shape.native))
        case .opacity(let opacity): return AnyView(view.opacity(opacity))
        case .offset(let x, let y): return AnyView(view.offset(x: x, y: y))
        case .rotationEffect(let degrees): return AnyView(view.rotationEffect(.degrees(degrees)))
        case .shadow(let color, let radius, let x, let y):
            return AnyView(view.shadow(color: color.native, radius: radius, x: x, y: y))
        case .lineLimit(let limit): return AnyView(view.lineLimit(limit))
        case .multilineTextAlignment(let alignment):
            return AnyView(view.multilineTextAlignment(alignment.native))
        case .tracking(let value): return AnyView(view.tracking(value))
        case .monospacedDigit: return AnyView(view.monospacedDigit())
        case .scaledToFill: return AnyView(view.scaledToFill())
        case .scaledToFit: return AnyView(view.scaledToFit())
        case .resizable, .fill, .stroke:
            preconditionFailure("Receiver-specific modifiers must be consumed before view erasure.")
        }
    }

    private func render(_ background: ScriptBackground) -> AnyView {
        switch background {
        case .color(let color): return AnyView(color.native)
        case .linearGradient(let gradient): return AnyView(gradient.native)
        case .node(let node): return render(node)
        }
    }

    private static func validate(
        _ node: ScriptNode,
        images: [String: Image]
    ) throws(RenderError) {
        switch node.kind {
        case .image(.asset(let name)):
            guard images[name] != nil else { throw .missingImage(name) }
        case .vStack(_, _, let children), .hStack(_, _, let children), .zStack(_, let children):
            for child in children { try validate(child, images: images) }
        default: break
        }
        for (index, modifier) in node.modifiers.enumerated() {
            switch modifier {
            case .resizable:
                guard index == 0, case .image = node.kind else { throw .invalidReceiver }
            case .fill, .stroke:
                guard index == 0, case .shape = node.kind else { throw .invalidReceiver }
            case .background(.node(let child)), .overlay(.node(let child)):
                try validate(child, images: images)
            default: break
            }
        }
    }
}
