import AppKit
import SwiftUI
import SwiftUIScript
import SwiftUIScriptCompiler
import SwiftUIScriptCore
import Testing

@MainActor
struct RenderingTests {
    @Test
    func readmeExampleCompilesAndRenders() throws {
        let package = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let readme = try String(contentsOf: package.appending(path: "README.md"), encoding: .utf8)
        let source = try #require(readme.range(of: "let source = #\"\"\"\n"))
        let end = try #require(
            readme.range(of: "\n\"\"\"#", range: source.upperBound..<readme.endIndex))
        let document = try ScriptCompiler().compile(
            String(readme[source.upperBound..<end.lowerBound]))
        let view = try ScriptView(document)
        #expect(try !pixels(view).isEmpty)
    }

    @Test
    func orderedModifiersMatchNativePixels() throws {
        let compiler = ScriptCompiler()
        let first = try ScriptView(
            compiler.compile(
                "Rectangle().fill(Color.blue).frame(width: 40, height: 20).padding(12).background(Color.red)"
            ))
        let second = try ScriptView(
            compiler.compile(
                "Rectangle().fill(Color.blue).frame(width: 40, height: 20).background(Color.red).padding(12)"
            ))
        let expectedFirst = Rectangle().fill(.blue).frame(width: 40, height: 20).padding(12)
            .background(.red)
        let expectedSecond = Rectangle().fill(.blue).frame(width: 40, height: 20).background(.red)
            .padding(12)
        let firstPixels = try pixels(first)
        let secondPixels = try pixels(second)
        #expect(try firstPixels == pixels(expectedFirst))
        #expect(try secondPixels == pixels(expectedSecond))
        #expect(firstPixels != secondPixels)

        let stack = try ScriptView(
            compiler.compile(
                """
                VStack(alignment: .leading, spacing: 8) {
                    Text("Native layout").font(.system(size: 18, weight: .semibold))
                    Rectangle().fill(Color.blue).frame(width: 90, height: 12)
                }.padding(10)
                """))
        let expectedStack = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Native layout").font(.system(size: 18, weight: .semibold))
            Rectangle().fill(.blue).frame(width: 90, height: 12)
        }.padding(10)
        #expect(try pixels(stack) == pixels(expectedStack))
    }

    @Test
    func hostImageResolutionFailsBeforeRendering() throws {
        let document = try ScriptCompiler().compile(
            "Image(asset: \"cover\").resizable().frame(width: 80, height: 80)")
        #expect(throws: RenderError.missingImage("cover")) { try ScriptView(document) }
        // Exercise host image binding without depending on system glyph rasterization.
        let bitmap = NSImage(size: CGSize(width: 8, height: 8), flipped: false) { rect in
            NSColor(red: 1, green: 0, blue: 0, alpha: 1).setFill()
            rect.fill()
            return true
        }
        let image = Image(nsImage: bitmap)
        let resolved = try ScriptView(document, images: ["cover": image])
        #expect(try pixels(resolved) == pixels(image.resizable().frame(width: 80, height: 80)))
        let invalid = ScriptDocument(
            root: ScriptNode(kind: .text("Invalid"), modifiers: [.resizable]))
        #expect(throws: RenderError.invalidReceiver) { try ScriptView(invalid) }
    }

    @Test
    func everyWidgetPreviewScriptCompilesAndRenders() throws {
        let package = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let previewFiles: [(file: String, name: String, family: String, proposal: CGSize)] = [
            ("MusicPreview.swift", "Music", "systemMedium", CGSize(width: 306, height: 137)),
            ("FocusPreview.swift", "Focus", "systemSmall", CGSize(width: 137, height: 137)),
            ("FlightPreview.swift", "Flight", "systemMedium", CGSize(width: 306, height: 137)),
            ("LocationPreview.swift", "Location", "systemLarge", CGSize(width: 306, height: 306)),
            ("WeatherPreview.swift", "Weather", "systemMedium", CGSize(width: 306, height: 137)),
            ("NewsPreview.swift", "News", "systemLarge", CGSize(width: 306, height: 306)),
            ("InboxPreview.swift", "Inbox", "systemMedium", CGSize(width: 306, height: 137)),
            (
                "QuickNotePreview.swift", "Quick note", "systemSmall",
                CGSize(width: 137, height: 137)
            ),
            (
                "MoodBoardPreview.swift", "Mood board", "systemLarge",
                CGSize(width: 306, height: 306)
            ),
        ]
        let pattern = try NSRegularExpression(pattern: "#\"\"\"([\\s\\S]*?)\"\"\"#")
        let assets = package.appending(
            path: "Sources/SwiftUIScriptGallery/Resources/Gallery.xcassets")
        var images: [String: Image] = [:]
        for directory in try FileManager.default.contentsOfDirectory(
            at: assets, includingPropertiesForKeys: nil)
        where directory.pathExtension == "imageset" {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)
            let imageFile = try #require(
                files.first { ["jpg", "png", "jpeg"].contains($0.pathExtension) })
            let image = try #require(NSImage(contentsOf: imageFile))
            let name = directory.deletingPathExtension().lastPathComponent.lowercased()
            images[name] = Image(nsImage: image)
        }
        for preview in previewFiles {
            let file = package.appending(path: "Sources/SwiftUIScriptGallery/\(preview.file)")
            let source = try String(contentsOf: file, encoding: .utf8)
            #expect(
                source.contains(
                    "#Preview(\"\(preview.name) · static sample\", as: .\(preview.family))"))
            let text = source as NSString
            let matches = pattern.matches(
                in: source, range: NSRange(location: 0, length: text.length))
            try #require(matches.count == 1)
            let script = text.substring(with: matches[0].range(at: 1))
            let document = try ScriptCompiler().compile(script)
            let view = try ScriptView(document, images: images)
            let rendered = try renderedImage(
                view,
                proposedSize: ProposedViewSize(
                    width: preview.proposal.width,
                    height: preview.proposal.height
                )
            )
            #expect(
                rendered.width <= Int(preview.proposal.width),
                "\(preview.name) width \(rendered.width) exceeds proposal \(Int(preview.proposal.width))"
            )
            #expect(
                rendered.height <= Int(preview.proposal.height),
                "\(preview.name) height \(rendered.height) exceeds proposal \(Int(preview.proposal.height))"
            )
            let bitmap = try #require(rendered.dataProvider?.data)
            #expect(!(bitmap as Data).isEmpty)
        }
    }

    private func renderedImage<V: View>(
        _ view: V,
        proposedSize: ProposedViewSize? = nil
    ) throws -> CGImage {
        _ = NSApplication.shared
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        if let proposedSize {
            renderer.proposedSize = proposedSize
        }
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    private func pixels<V: View>(
        _ view: V,
        proposedSize: ProposedViewSize? = nil
    ) throws -> Data {
        let image = try renderedImage(view, proposedSize: proposedSize)
        let data = try #require(image.dataProvider?.data)
        return data as Data
    }
}
