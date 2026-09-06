import Foundation
import Testing
import SwiftUIScriptCore

struct ScriptDocumentCodecTests {
    @Test
    func roundTripPreservesCompiledDocument() throws {
        let document = ScriptDocument(
            root: ScriptNode(
                kind: .vStack(
                    alignment: .leading,
                    spacing: 8,
                    children: [
                        ScriptNode(
                            kind: .text("Headline"),
                            modifiers: [
                                .font(.system(size: 18, weight: .semibold, design: .rounded)),
                                .foregroundStyle(.named(.primary)),
                            ]
                        ),
                        ScriptNode(
                            kind: .shape(.roundedRectangle(cornerRadius: 12)),
                            modifiers: [
                                .fill(.rgb(red: 0.2, green: 0.4, blue: 0.8, opacity: 1)),
                                .frame(
                                    .flexible(
                                        minWidth: .value(20),
                                        idealWidth: .value(80),
                                        maxWidth: .infinity,
                                        minHeight: nil,
                                        idealHeight: .value(40),
                                        maxHeight: nil,
                                        alignment: .center
                                    )
                                ),
                            ]
                        ),
                    ]
                )
            )
        )
        let codec = try ScriptDocumentCodec()
        let encoded = try codec.encode(document)
        let decoded = try codec.decode(encoded)

        #expect(decoded == document)
        #expect(try codec.encode(decoded) == encoded)
        #expect(ScriptDocumentCodec.mediaType == "application/vnd.swiftuiscript+json")
    }

    @Test
    func rejectsUnknownFieldsAndUnsupportedVersions() throws {
        let codec = try ScriptDocumentCodec()
        let document = ScriptDocument(root: ScriptNode(kind: .text("value")))
        let encoded = try codec.encode(document)

        var unknown = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        unknown["unexpected"] = true
        let unknownData = try JSONSerialization.data(withJSONObject: unknown, options: [])
        do {
            _ = try codec.decode(unknownData)
            Issue.record("Expected the unknown field to be rejected.")
        } catch {
            #expect(error == .unknownField("unexpected"))
        }

        var unsupported = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        unsupported["formatVersion"] = 99
        let unsupportedData = try JSONSerialization.data(withJSONObject: unsupported, options: [])
        do {
            _ = try codec.decode(unsupportedData)
            Issue.record("Expected the unsupported version to be rejected.")
        } catch {
            #expect(error == .unsupportedVersion(99))
        }

        #expect(throws: ScriptDocumentCodec.Error.unsupportedVersion(99)) {
            try codec.encode(ScriptDocument(root: document.root, formatVersion: 99))
        }
    }

    @Test
    func rejectsMalformedAndOverBudgetDocuments() throws {
        let codec = try ScriptDocumentCodec()
        #expect(throws: ScriptDocumentCodec.Error.malformedJSON) {
            try codec.decode(Data("not-json".utf8))
        }

        let byteLimited = try ScriptDocumentCodec(maximumBytes: 24)
        #expect(throws: ScriptDocumentCodec.Error.byteLimitExceeded(25)) {
            try byteLimited.decode(Data(repeating: 0x20, count: 25))
        }

        let nodeLimited = try ScriptDocumentCodec(maximumNodes: 2)
        let manyNodes = ScriptDocument(
            root: ScriptNode(
                kind: .vStack(
                    alignment: .center,
                    spacing: nil,
                    children: [
                        ScriptNode(kind: .text("one")),
                        ScriptNode(kind: .text("two")),
                    ]
                )
            )
        )
        #expect(throws: ScriptDocumentCodec.Error.nodeLimitExceeded(3)) {
            try nodeLimited.encode(manyNodes)
        }
        let encodedManyNodes = try codec.encode(manyNodes)
        #expect(throws: ScriptDocumentCodec.Error.nodeLimitExceeded(3)) {
            try nodeLimited.decode(encodedManyNodes)
        }

        let deepDocument = ScriptDocument(root: nestedNode(count: 4))
        let depthLimited = try ScriptDocumentCodec(maximumDepth: 3)
        #expect(throws: ScriptDocumentCodec.Error.depthLimitExceeded(4)) {
            try depthLimited.encode(deepDocument)
        }
        let encodedDeepDocument = try codec.encode(deepDocument)
        #expect(throws: ScriptDocumentCodec.Error.depthLimitExceeded(4)) {
            try depthLimited.decode(encodedDeepDocument)
        }
    }

    @Test
    func rejectsNonFiniteAndOverLimitNumbers() throws {
        let nonFinite = ScriptDocument(
            root: ScriptNode(kind: .text("value"), modifiers: [.opacity(.infinity)])
        )
        let codec = try ScriptDocumentCodec()
        #expect(throws: ScriptDocumentCodec.Error.nonFiniteNumber) {
            try codec.encode(nonFinite)
        }

        let limited = try ScriptDocumentCodec(maximumNumericMagnitude: 10)
        let overLimit = ScriptDocument(
            root: ScriptNode(
                kind: .text("value"),
                modifiers: [.frame(.fixed(width: 11, height: nil, alignment: .center))]
            )
        )
        #expect(throws: ScriptDocumentCodec.Error.numericLimitExceeded(11)) {
            try limited.encode(overLimit)
        }
    }

    private func nestedNode(count: Int) -> ScriptNode {
        guard count > 1 else { return ScriptNode(kind: .text("leaf")) }
        return ScriptNode(
            kind: .vStack(
                alignment: .center,
                spacing: nil,
                children: [nestedNode(count: count - 1)]
            )
        )
    }
}
