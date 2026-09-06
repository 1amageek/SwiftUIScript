import SwiftUIScriptCompiler
import SwiftUIScriptCore
import Testing

struct QualificationTests {
    @Test
    func rejectsUnsupportedAndInvalidSource() {
        let rejected = [
            "Text(\"unfinished\"",
            "WebView(url: \"https://example.com\")",
            "Text(\"value\").unknownModifier()",
            "Text(\"value\", invented: 7)",
            "Text(\"value\").frame(wdth: 7)",
            "Text(\"value\").frame(width: -1)",
            "Text(\"value\").frame(width: 20, maxHeight: 40)",
            "Text(\"value\").frame(minWidth: 100, maxWidth: 20)",
            "Text(\"value\").frame(width: 1 / 0)",
            "Text(\"value\").foregroundStyle(Color(hex: \"not-a-color\"))",
            "Text(\"value\").resizable()",
            "Image(systemName: \"leaf\").frame(width: 20).resizable()",
            "Text(\"value\").padding(5, 10)",
            "Text(\"value\").opacity(1, 2)",
            "Text(\"value\") { Text(\"ignored\") }",
            "VStack(99, invented: 7) { Text(\"value\") }",
            "Image(systemName: \"leaf\", asset: \"cover\")",
            "HStack(alignment: .leading) { Text(\"value\") }",
            "VStack(alignment: .top) { Text(\"value\") }",
            "Text(\"value\").font(.system(size: -1))",
            "RoundedRectangle(cornerRadius: -1)",
            "Text(\"value\").lineLimit(1e30)",
            "ForEach(9223372036854775807...9223372036854775807) { tick in Text(\"value\") }",
            "VStack { ForEach(0..<2) { tick in Text(\"value\") }; Spacer().frame(width: tick) }",
            "ForEach(0..<1) { first, ignored in Text(\"value\") }",
            "ForEach(0..<1) { [capture] tick in Text(\"value\") }",
            "Rectangle().frame(width: 9223372036854775807 + 1)",
        ]
        for source in rejected {
            #expect(throws: ScriptError.self, "\(source)") { try ScriptCompiler().compile(source) }
        }
    }

    @Test
    func expandsLoopAndPreservesFrameOverloads() throws {
        let document = try ScriptCompiler().compile(
            """
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<3) { tick in
                    Rectangle().frame(width: 10 + tick * 5, height: 3)
                }
            }.frame(minWidth: 20, idealWidth: 30, maxWidth: .infinity, alignment: .leading)
            """)
        guard case .vStack(let alignment, let spacing, let children) = document.root.kind else {
            Issue.record("Expected a vertical stack")
            return
        }
        #expect(alignment == .leading)
        #expect(spacing == 4)
        #expect(children.count == 3)
        #expect(
            children.map(\.modifiers)
                == [10.0, 15.0, 20.0].map {
                    [.frame(.fixed(width: $0, height: 3, alignment: .center))]
                })
        #expect(
            document.root.modifiers == [
                .frame(
                    .flexible(
                        minWidth: .value(20), idealWidth: .value(30), maxWidth: .infinity,
                        minHeight: nil, idealHeight: nil, maxHeight: nil, alignment: .leading
                    ))
            ])
    }

    @Test
    func rejectsUnboundedExpansion() {
        let compiler = ScriptCompiler(
            profile: .init(maxDepth: 12, maxExpandedNodes: 8, maxIterations: 8))
        #expect(throws: ScriptError.self) {
            try compiler.compile("VStack { ForEach(0..<100) { index in Text(\"Bounded\") } }")
        }
        let deep =
            String(repeating: "VStack { ", count: 20) + "Text(\"Deep\")"
            + String(repeating: " }", count: 20)
        #expect(throws: ScriptError.self) { try compiler.compile(deep) }
        let aggregate = ScriptCompiler(profile: .init(maxExpandedNodes: 100, maxIterations: 8))
        #expect(throws: ScriptError.self) {
            try aggregate.compile(
                "VStack { ForEach(0..<5) { i in Text(\"A\") }; ForEach(0..<5) { i in Text(\"B\") } }"
            )
        }
        #expect(throws: ScriptError.self) {
            try compiler.compile(
                "Text(\"Root\").background { VStack { Text(\"1\"); Text(\"2\"); Text(\"3\"); Text(\"4\") } }.overlay { VStack { Text(\"5\"); Text(\"6\"); Text(\"7\"); Text(\"8\") } }"
            )
        }
    }
}
