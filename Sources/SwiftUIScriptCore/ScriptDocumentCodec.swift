import Foundation

/// Encodes and decodes a bounded, versioned `ScriptDocument` transport.
public struct ScriptDocumentCodec: Sendable {
    public static let mediaType = "application/vnd.swiftuiscript+json"
    public static let defaultMaximumBytes = 64 * 1024
    public static let defaultMaximumNodes = 4_096
    public static let defaultMaximumDepth = 64
    public static let defaultMaximumNumericMagnitude = Double.greatestFiniteMagnitude

    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidConfiguration
        case malformedJSON
        case invalidDocument(String)
        case unsupportedVersion(Int)
        case unknownField(String)
        case byteLimitExceeded(Int)
        case nodeLimitExceeded(Int)
        case depthLimitExceeded(Int)
        case nonFiniteNumber
        case numericLimitExceeded(Double)
    }

    public let maximumBytes: Int
    public let maximumNodes: Int
    public let maximumDepth: Int
    public let maximumNumericMagnitude: Double

    public init(
        maximumBytes: Int = ScriptDocumentCodec.defaultMaximumBytes,
        maximumNodes: Int = ScriptDocumentCodec.defaultMaximumNodes,
        maximumDepth: Int = ScriptDocumentCodec.defaultMaximumDepth,
        maximumNumericMagnitude: Double = ScriptDocumentCodec.defaultMaximumNumericMagnitude
    ) throws(Error) {
        guard maximumBytes > 0,
            maximumNodes > 0,
            maximumDepth > 0,
            maximumNumericMagnitude.isFinite,
            maximumNumericMagnitude > 0
        else {
            throw .invalidConfiguration
        }
        self.maximumBytes = maximumBytes
        self.maximumNodes = maximumNodes
        self.maximumDepth = maximumDepth
        self.maximumNumericMagnitude = maximumNumericMagnitude
    }

    public func encode(_ document: ScriptDocument) throws(Error) -> Data {
        guard document.formatVersion == ScriptDocument.formatVersion else {
            throw .unsupportedVersion(document.formatVersion)
        }
        try validate(document)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(document)
            guard data.count <= maximumBytes else {
                throw Error.byteLimitExceeded(data.count)
            }
            return data
        } catch let error as Error {
            throw error
        } catch {
            throw .invalidDocument(error.localizedDescription)
        }
    }

    public func decode(_ data: Data) throws(Error) -> ScriptDocument {
        guard data.count <= maximumBytes else {
            throw .byteLimitExceeded(data.count)
        }
        let object = try jsonObject(from: data)
        try validateJSONNumbers(object)

        let document: ScriptDocument
        do {
            document = try JSONDecoder().decode(ScriptDocument.self, from: data)
        } catch let error as Error {
            throw error
        } catch {
            throw .invalidDocument(error.localizedDescription)
        }
        guard document.formatVersion == ScriptDocument.formatVersion else {
            throw .unsupportedVersion(document.formatVersion)
        }
        try validate(document)

        let canonical = try encode(document)
        let canonicalObject = try jsonObject(from: canonical)
        guard jsonEqual(object, canonicalObject) else {
            if let field = firstUnknownField(in: object, comparedTo: canonicalObject) {
                throw .unknownField(field)
            }
            throw .invalidDocument("The JSON does not match the canonical document schema.")
        }
        return document
    }

    private func validate(_ document: ScriptDocument) throws(Error) {
        var state = ScriptValidationState(codec: self)
        try state.validate(document.root, depth: 1)
    }

    private func jsonObject(from data: Data) throws(Error) -> Any {
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            guard object is [String: Any] else {
                throw Error.invalidDocument("The document root must be a JSON object.")
            }
            return object
        } catch let error as Error {
            throw error
        } catch {
            throw .malformedJSON
        }
    }

    private func validateJSONNumbers(_ value: Any, depth: Int = 0) throws(Error) {
        let structuralLimit = maximumDepth > (Int.max - 8) / 4
            ? Int.max
            : maximumDepth * 4 + 8
        guard depth <= structuralLimit else {
            throw .depthLimitExceeded(depth)
        }
        if let dictionary = value as? [String: Any] {
            for child in dictionary.values {
                try validateJSONNumbers(child, depth: depth + 1)
            }
        } else if let array = value as? [Any] {
            for child in array {
                try validateJSONNumbers(child, depth: depth + 1)
            }
        } else if let number = value as? NSNumber,
            !isBoolean(number)
        {
            let double = number.doubleValue
            guard double.isFinite else {
                throw .nonFiniteNumber
            }
            guard abs(double) <= maximumNumericMagnitude else {
                throw .numericLimitExceeded(double)
            }
        }
    }

    private func isBoolean(_ number: NSNumber) -> Bool {
        String(cString: number.objCType) == "c" || String(cString: number.objCType) == "B"
    }
}

private struct ScriptValidationState {
    let codec: ScriptDocumentCodec
    var nodes = 0

    mutating func validate(_ node: ScriptNode, depth: Int) throws(ScriptDocumentCodec.Error) {
        guard depth <= codec.maximumDepth else {
            throw .depthLimitExceeded(depth)
        }
        nodes += 1
        guard nodes <= codec.maximumNodes else {
            throw .nodeLimitExceeded(nodes)
        }
        try validate(node.kind, depth: depth)
        for modifier in node.modifiers {
            try validate(modifier, depth: depth)
        }
    }

    mutating func validate(_ kind: ScriptNodeKind, depth: Int) throws(ScriptDocumentCodec.Error) {
        switch kind {
        case .text, .divider:
            break
        case let .label(_, systemImage):
            guard !systemImage.isEmpty else {
                throw .invalidDocument("A label system image must not be empty.")
            }
        case let .image(image):
            switch image {
            case let .systemName(name), let .asset(name):
                guard !name.isEmpty else {
                    throw .invalidDocument("An image name must not be empty.")
                }
            }
        case let .vStack(_, spacing, children):
            try validate(spacing)
            for child in children {
                try validate(child, depth: depth + 1)
            }
        case let .hStack(_, spacing, children):
            try validate(spacing)
            for child in children {
                try validate(child, depth: depth + 1)
            }
        case let .zStack(_, children):
            for child in children {
                try validate(child, depth: depth + 1)
            }
        case let .spacer(minLength):
            try validate(minLength)
        case let .shape(shape):
            try validate(shape)
        case let .color(color):
            try validate(color)
        case let .linearGradient(gradient):
            try validate(gradient)
        }
    }

    mutating func validate(_ modifier: ScriptModifier, depth: Int) throws(ScriptDocumentCodec.Error) {
        switch modifier {
        case let .font(font):
            try validate(font)
        case let .foregroundStyle(color), let .fill(color):
            try validate(color)
        case let .frame(frame):
            try validate(frame)
        case let .padding(_, amount):
            try validate(amount)
        case let .background(background), let .overlay(background):
            try validate(background, depth: depth)
        case let .clipShape(shape):
            try validate(shape)
        case let .opacity(value), let .tracking(value):
            try validate(value)
        case let .offset(x, y):
            try validate(x)
            try validate(y)
        case let .rotationEffect(degrees):
            try validate(degrees)
        case let .shadow(color, radius, x, y):
            try validate(color)
            try validate(radius)
            try validate(x)
            try validate(y)
        case let .lineLimit(limit):
            try validate(limit)
        case .multilineTextAlignment, .monospacedDigit, .resizable, .scaledToFill, .scaledToFit:
            break
        case let .stroke(color, lineWidth):
            try validate(color)
            try validate(lineWidth)
        }
    }

    mutating func validate(_ background: ScriptBackground, depth: Int) throws(ScriptDocumentCodec.Error) {
        switch background {
        case let .color(color):
            try validate(color)
        case let .linearGradient(gradient):
            try validate(gradient)
        case let .node(node):
            try validate(node, depth: depth + 1)
        }
    }

    mutating func validate(_ frame: ScriptFrame) throws(ScriptDocumentCodec.Error) {
        switch frame {
        case let .fixed(width, height, _):
            try validate(width)
            try validate(height)
        case let .flexible(minWidth, idealWidth, maxWidth, minHeight, idealHeight, maxHeight, _):
            try validate(minWidth)
            try validate(idealWidth)
            try validate(maxWidth)
            try validate(minHeight)
            try validate(idealHeight)
            try validate(maxHeight)
        }
    }

    mutating func validate(_ font: ScriptFont) throws(ScriptDocumentCodec.Error) {
        if case let .system(size, _, _) = font {
            try validate(size)
        }
    }

    mutating func validate(_ color: ScriptColor) throws(ScriptDocumentCodec.Error) {
        switch color {
        case let .hex(value):
            guard isValidHexColor(value) else {
                throw .invalidDocument("A hex color must contain six or eight hexadecimal digits.")
            }
        case let .rgb(red, green, blue, opacity):
            try validate(red)
            try validate(green)
            try validate(blue)
            try validate(opacity)
        case .named:
            break
        }
    }

    mutating func validate(_ gradient: ScriptLinearGradient) throws(ScriptDocumentCodec.Error) {
        for color in gradient.colors {
            try validate(color)
        }
    }

    mutating func validate(_ shape: ScriptShape) throws(ScriptDocumentCodec.Error) {
        if case let .roundedRectangle(cornerRadius) = shape {
            try validate(cornerRadius)
        }
    }

    mutating func validate(_ dimension: ScriptDimension?) throws(ScriptDocumentCodec.Error) {
        if case let .value(value) = dimension {
            try validate(value)
        }
    }

    mutating func validate(_ value: Double?) throws(ScriptDocumentCodec.Error) {
        if let value {
            try validate(value)
        }
    }

    mutating func validate(_ value: Double) throws(ScriptDocumentCodec.Error) {
        guard value.isFinite else {
            throw .nonFiniteNumber
        }
        guard abs(value) <= codec.maximumNumericMagnitude else {
            throw .numericLimitExceeded(value)
        }
    }

    mutating func validate(_ value: Int) throws(ScriptDocumentCodec.Error) {
        let double = Double(value)
        guard abs(double) <= codec.maximumNumericMagnitude else {
            throw .numericLimitExceeded(double)
        }
    }
}

private func isValidHexColor(_ string: String) -> Bool {
    let value = string.hasPrefix("#") ? String(string.dropFirst()) : string
    guard value.count == 6 || value.count == 8 else { return false }
    return UInt64(value, radix: 16) != nil
}

private func jsonEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    switch (lhs, rhs) {
    case let (lhs as [String: Any], rhs as [String: Any]):
        guard lhs.count == rhs.count else { return false }
        return lhs.allSatisfy { key, value in
            guard let other = rhs[key] else { return false }
            return jsonEqual(value, other)
        }
    case let (lhs as [Any], rhs as [Any]):
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { jsonEqual($0.0, $0.1) }
    case let (lhs as NSNumber, rhs as NSNumber):
        if String(cString: lhs.objCType) == "c" || String(cString: lhs.objCType) == "B" {
            return lhs.boolValue == rhs.boolValue
        }
        return lhs.doubleValue == rhs.doubleValue
    case let (lhs as String, rhs as String):
        return lhs == rhs
    case (_ as NSNull, _ as NSNull):
        return true
    default:
        return false
    }
}

private func firstUnknownField(in input: Any, comparedTo canonical: Any, path: String = "$") -> String? {
    if let inputDictionary = input as? [String: Any],
        let canonicalDictionary = canonical as? [String: Any]
    {
        for key in inputDictionary.keys.sorted() where canonicalDictionary[key] == nil {
            return path == "$" ? key : "\(path).\(key)"
        }
        for key in inputDictionary.keys.sorted() {
            guard let inputValue = inputDictionary[key], let canonicalValue = canonicalDictionary[key]
            else { continue }
            if let field = firstUnknownField(
                in: inputValue,
                comparedTo: canonicalValue,
                path: path == "$" ? key : "\(path).\(key)"
            ) {
                return field
            }
        }
        return nil
    }
    if let inputArray = input as? [Any], let canonicalArray = canonical as? [Any] {
        for (index, value) in inputArray.enumerated() where index < canonicalArray.count {
            if let field = firstUnknownField(
                in: value,
                comparedTo: canonicalArray[index],
                path: "\(path)[\(index)]"
            ) {
                return field
            }
        }
        return nil
    }
    return nil
}
