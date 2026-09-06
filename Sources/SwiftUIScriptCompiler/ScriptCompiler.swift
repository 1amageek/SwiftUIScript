import SwiftParser
import SwiftSyntax
import SwiftUIScriptCore

public struct ScriptCompiler: Sendable {
    public struct Profile: Sendable, Equatable {
        public let maxSourceBytes: Int
        public let maxDepth: Int
        public let maxExpandedNodes: Int
        public let maxIterations: Int
        public let maxExpressionSteps: Int

        public init(
            maxSourceBytes: Int = 64 * 1024,
            maxDepth: Int = 64,
            maxExpandedNodes: Int = 4_096,
            maxIterations: Int = 256,
            maxExpressionSteps: Int = 8_192
        ) {
            self.maxSourceBytes = maxSourceBytes
            self.maxDepth = maxDepth
            self.maxExpandedNodes = maxExpandedNodes
            self.maxIterations = maxIterations
            self.maxExpressionSteps = maxExpressionSteps
        }

        public static let preview = Profile()
    }

    public let profile: Profile

    public init(profile: Profile = .preview) {
        self.profile = profile
    }

    public func compile(_ source: String) throws(ScriptError) -> ScriptDocument {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw .emptySource
        }
        guard source.utf8.count <= profile.maxSourceBytes else {
            throw .sourceTooLarge(limit: profile.maxSourceBytes)
        }

        // ponytail: cap parser nesting for cooperative-thread debug stacks; qualify a larger limit before raising it.
        let file = Parser.parse(source: source, maximumNestingLevel: min(profile.maxDepth, 12))
        guard !file.hasError else {
            throw .parseRecovery(location: location(of: file))
        }

        var context = Context(profile: profile)
        let values = try compileStatements(file.statements, context: &context)
        guard values.count == 1 else {
            throw .invalidValue(
                reason: values.isEmpty
                    ? "The source must produce one root view."
                    : "The source produced more than one root view.",
                location: ScriptSourceLocation(utf8Offset: 0)
            )
        }
        guard case .node(let root, _) = try viewValue(values[0], syntax: file, context: &context)
        else {
            throw .invalidValue(
                reason: "The root expression is not a view.",
                location: ScriptSourceLocation(utf8Offset: 0))
        }
        return ScriptDocument(root: root)
    }
}

extension ScriptCompiler {
    fileprivate enum Category {
        case view
        case image
        case shape
    }

    fileprivate enum Value {
        case string(String)
        case integer(Int)
        case number(Double)
        case boolean(Bool)
        case color(ScriptColor)
        case font(ScriptFont)
        case weight(ScriptFontWeight)
        case design(ScriptFontDesign)
        case shape(ScriptShape)
        case node(ScriptNode, Category)
        case image(ScriptImage)
        case gradient(ScriptLinearGradient)
        case alignment(ScriptAlignment)
        case verticalAlignment(ScriptVerticalAlignment)
        case edge(ScriptEdge)
        case textAlignment(ScriptTextAlignment)
        case dimension(ScriptDimension)
        case unitPoint(ScriptUnitPoint)
        case array([Value])
        case range(Range<Int>)
    }

    fileprivate struct Context {
        var profile: Profile
        var variables: [String: Value] = [:]
        var depth = 0
        var expandedNodes = 0
        var iterations = 0
        var expressionSteps = 0

        mutating func enter(_ syntax: some SyntaxProtocol) throws(ScriptError) {
            depth += 1
            guard depth <= profile.maxDepth else {
                throw .budgetExceeded(
                    kind: "depth",
                    limit: profile.maxDepth,
                    location: ScriptSourceLocation(
                        utf8Offset: syntax.positionAfterSkippingLeadingTrivia.utf8Offset)
                )
            }
        }

        mutating func leave() {
            depth -= 1
        }

        mutating func countNode(_ syntax: some SyntaxProtocol) throws(ScriptError) {
            expandedNodes += 1
            guard expandedNodes <= profile.maxExpandedNodes else {
                throw .budgetExceeded(
                    kind: "expanded node",
                    limit: profile.maxExpandedNodes,
                    location: ScriptSourceLocation(
                        utf8Offset: syntax.positionAfterSkippingLeadingTrivia.utf8Offset)
                )
            }
        }

        mutating func countExpression(_ syntax: some SyntaxProtocol) throws(ScriptError) {
            expressionSteps += 1
            guard expressionSteps <= profile.maxExpressionSteps else {
                throw .budgetExceeded(
                    kind: "expression",
                    limit: profile.maxExpressionSteps,
                    location: ScriptSourceLocation(
                        utf8Offset: syntax.positionAfterSkippingLeadingTrivia.utf8Offset)
                )
            }
        }
    }

    fileprivate func compileStatements(
        _ statements: CodeBlockItemListSyntax,
        context: inout Context
    ) throws(ScriptError) -> [Value] {
        let outerVariables = context.variables
        defer { context.variables = outerVariables }
        var values: [Value] = []
        for statement in statements {
            switch statement.item {
            case .decl(let declaration):
                try compileDeclaration(declaration, context: &context)
            case .expr(let expression):
                values.append(try evaluate(expression, context: &context))
            case .stmt(let statement):
                throw unsupported(statement, name: "statement")
            }
        }
        return values.flatMap { value in
            if case .array(let values) = value {
                return values
            }
            return [value]
        }
    }

    fileprivate func compileDeclaration(
        _ declaration: DeclSyntax,
        context: inout Context
    ) throws(ScriptError) {
        guard let variable = declaration.as(VariableDeclSyntax.self) else {
            throw unsupported(declaration, name: "declaration")
        }
        guard variable.bindingSpecifier.tokenKind == .keyword(.let) else {
            throw unsupported(variable, name: "mutable declaration")
        }
        guard variable.bindings.count == 1, let binding = variable.bindings.first else {
            throw unsupported(variable, name: "multiple declaration")
        }
        guard variable.attributes.isEmpty, variable.modifiers.isEmpty,
            binding.typeAnnotation == nil,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
            let initializer = binding.initializer
        else {
            throw invalid(variable, reason: "A let declaration needs one initialized identifier.")
        }
        context.variables[identifier.identifier.text] = try evaluate(
            initializer.value, context: &context)
    }

    fileprivate func evaluate(
        _ expression: ExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> Value {
        try context.enter(expression)
        defer { context.leave() }
        try context.countExpression(expression)
        if let literal = expression.as(StringLiteralExprSyntax.self),
            let value = literal.representedLiteralValue
        {
            return .string(value)
        }
        if let literal = expression.as(IntegerLiteralExprSyntax.self),
            let value = literal.representedLiteralValue
        {
            return .integer(value)
        }
        if let literal = expression.as(FloatLiteralExprSyntax.self),
            let value = literal.representedLiteralValue
        {
            return .number(value)
        }
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return try evaluateReference(reference, context: context)
        }
        if let member = expression.as(MemberAccessExprSyntax.self) {
            return try evaluateMember(member, context: context)
        }
        if let call = expression.as(FunctionCallExprSyntax.self) {
            return try evaluateCall(call, context: &context)
        }
        if let array = expression.as(ArrayExprSyntax.self) {
            var values: [Value] = []
            for element in array.elements {
                values.append(try evaluate(element.expression, context: &context))
            }
            return .array(values)
        }
        if let sequence = expression.as(SequenceExprSyntax.self) {
            return try evaluateSequence(sequence, context: &context)
        }
        if let prefix = expression.as(PrefixOperatorExprSyntax.self) {
            return try evaluatePrefix(prefix, context: &context)
        }
        if let tuple = expression.as(TupleExprSyntax.self), tuple.elements.count == 1,
            let element = tuple.elements.first, element.label == nil
        {
            return try evaluate(element.expression, context: &context)
        }
        throw unsupported(expression, name: expression.syntaxNodeTypeName)
    }

    fileprivate func evaluateReference(
        _ reference: DeclReferenceExprSyntax,
        context: Context
    ) throws(ScriptError) -> Value {
        let name = reference.baseName.text
        if let value = context.variables[name] {
            return value
        }
        switch name {
        case "true":
            return .boolean(true)
        case "false":
            return .boolean(false)
        case "infinity":
            return .dimension(.infinity)
        default:
            throw unknown(reference, name: name)
        }
    }

    fileprivate func evaluateMember(
        _ member: MemberAccessExprSyntax,
        context: Context
    ) throws(ScriptError) -> Value {
        let name = member.declName.baseName.text
        guard let base = member.base else {
            return try evaluateStaticMember(name, syntax: member)
        }
        if let reference = base.as(DeclReferenceExprSyntax.self) {
            switch reference.baseName.text {
            case "Color":
                if let color = ScriptNamedColor(rawValue: name) {
                    return .color(.named(color))
                }
            case "Font":
                if let font = ScriptNamedFont(rawValue: name) {
                    return .font(.named(font))
                }
            default:
                break
            }
        }
        throw unknown(member, name: member.description)
    }

    fileprivate func evaluateStaticMember(
        _ name: String,
        syntax: some SyntaxProtocol
    ) throws(ScriptError) -> Value {
        if let font = ScriptNamedFont(rawValue: name) { return .font(.named(font)) }
        if let alignment = ScriptAlignment(rawValue: name) {
            return .alignment(alignment)
        }
        if let alignment = ScriptVerticalAlignment(rawValue: name) {
            return .verticalAlignment(alignment)
        }
        if let edge = ScriptEdge(rawValue: name) {
            return .edge(edge)
        }
        if let alignment = ScriptTextAlignment(rawValue: name) {
            return .textAlignment(alignment)
        }
        if let weight = ScriptFontWeight(rawValue: name) {
            return .weight(weight)
        }
        if let design = ScriptFontDesign(rawValue: name) {
            return .design(design)
        }
        if let unitPoint = ScriptUnitPoint(rawValue: name) {
            return .unitPoint(unitPoint)
        }
        if name == "infinity" {
            return .dimension(.infinity)
        }
        throw unknown(syntax, name: ".\(name)")
    }

    fileprivate func evaluateCall(
        _ call: FunctionCallExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> Value {
        let arguments = Array(call.arguments)
        try validateCall(call, name: functionName(call.calledExpression))
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self),
            let base = member.base
        {
            let receiver = try evaluate(base, context: &context)
            return try applyModifier(
                name: member.declName.baseName.text,
                receiver: receiver,
                call: call,
                context: &context
            )
        }

        let name = functionName(call.calledExpression)
        switch name {
        case "system":
            let size = try requiredNumber(
                arguments, label: "size", API: "Font.system", call: call, context: &context)
            try validate(size > 0, call: call, reason: "Font size must be positive.")
            let weight: ScriptFontWeight?
            if let value = try optionalValue(arguments, label: "weight", context: &context) {
                guard case .weight(let value) = value else {
                    throw invalid(
                        call, reason: "Font.system weight must be a supported font weight.")
                }
                weight = value
            } else {
                weight = nil
            }
            let design: ScriptFontDesign?
            if let value = try optionalValue(arguments, label: "design", context: &context) {
                guard case .design(let value) = value else {
                    throw invalid(
                        call, reason: "Font.system design must be a supported font design.")
                }
                design = value
            } else {
                design = nil
            }
            return .font(.system(size: size, weight: weight, design: design))
        case "degrees":
            let value = try requiredNumber(
                arguments, label: nil, API: ".degrees", call: call, context: &context)
            return .number(value)
        case "Text":
            let string = try requiredValue(
                arguments, label: nil, API: name, call: call, context: &context)
            guard case .string(let value) = string else {
                throw invalid(call, reason: "Text requires a string literal or string constant.")
            }
            return try node(.text(value), category: .view, syntax: call, context: &context)
        case "Image":
            if let argument = arguments.first(where: { $0.label?.text == "systemName" }) {
                let value = try evaluate(argument.expression, context: &context)
                guard case .string(let name) = value else {
                    throw invalid(argument, reason: "systemName requires a string.")
                }
                return try node(
                    .image(.systemName(name)), category: .image, syntax: call, context: &context)
            }
            if let argument = arguments.first(where: { $0.label?.text == "asset" }) {
                let value = try evaluate(argument.expression, context: &context)
                guard case .string(let name) = value else {
                    throw invalid(argument, reason: "asset requires a string.")
                }
                return try node(
                    .image(.asset(name)), category: .image, syntax: call, context: &context)
            }
            throw missing(call, label: "systemName or asset", API: name)
        case "VStack":
            let children = try builderChildren(call, context: &context)
            let alignment = try optionalAlignment(
                arguments, label: "alignment", default: .center, context: &context)
            try validate(
                [.leading, .center, .trailing].contains(alignment), call: call,
                reason: "VStack requires a horizontal alignment.")
            let spacing = try optionalNumber(arguments, label: "spacing", context: &context)
            return try node(
                .vStack(alignment: alignment, spacing: spacing, children: children),
                category: .view, syntax: call, context: &context)
        case "HStack":
            let children = try builderChildren(call, context: &context)
            let alignment = try optionalVerticalAlignment(
                arguments, label: "alignment", default: .center, context: &context)
            let spacing = try optionalNumber(arguments, label: "spacing", context: &context)
            return try node(
                .hStack(alignment: alignment, spacing: spacing, children: children),
                category: .view, syntax: call, context: &context)
        case "ZStack":
            let children = try builderChildren(call, context: &context)
            let alignment = try optionalAlignment(
                arguments, label: "alignment", default: .center, context: &context)
            return try node(
                .zStack(alignment: alignment, children: children), category: .view, syntax: call,
                context: &context)
        case "Spacer":
            let minimum = try optionalNumber(arguments, label: "minLength", context: &context)
            if let minimum {
                try validate(
                    minimum >= 0, call: call, reason: "Spacer minimum must be non-negative.")
            }
            return try node(
                .spacer(minLength: minimum), category: .view, syntax: call, context: &context)
        case "Divider":
            try rejectArguments(arguments, API: name, call: call)
            return try node(.divider, category: .view, syntax: call, context: &context)
        case "Rectangle":
            try rejectArguments(arguments, API: name, call: call)
            return try node(.shape(.rectangle), category: .shape, syntax: call, context: &context)
        case "RoundedRectangle":
            let radius = try requiredNumber(
                arguments, label: "cornerRadius", API: name, call: call, context: &context)
            try validate(radius >= 0, call: call, reason: "Corner radius must be non-negative.")
            return try node(
                .shape(.roundedRectangle(cornerRadius: radius)), category: .shape, syntax: call,
                context: &context)
        case "Circle":
            try rejectArguments(arguments, API: name, call: call)
            return try node(.shape(.circle), category: .shape, syntax: call, context: &context)
        case "Ellipse":
            try rejectArguments(arguments, API: name, call: call)
            return try node(.shape(.ellipse), category: .shape, syntax: call, context: &context)
        case "Capsule":
            try rejectArguments(arguments, API: name, call: call)
            return try node(.shape(.capsule), category: .shape, syntax: call, context: &context)
        case "Color":
            return try evaluateColor(arguments, call: call, context: &context)
        case "LinearGradient":
            return try evaluateGradient(arguments, call: call, context: &context)
        case "ForEach":
            return try evaluateForEach(arguments, call: call, context: &context)
        default:
            throw .unsupportedConstructor(name: name, location: location(of: call))
        }
    }

    fileprivate func applyModifier(
        name: String,
        receiver: Value,
        call: FunctionCallExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> Value {
        let receiver = try viewValue(receiver, syntax: call, context: &context)
        guard case .node(let base, let category) = receiver else {
            throw invalidModifier(call, name: name)
        }
        let arguments = Array(call.arguments)
        switch name {
        case "font":
            guard let value = try optionalValue(arguments, label: nil, context: &context),
                case .font(let font) = value
            else {
                throw invalid(call, reason: "font requires a supported font.")
            }
            return .node(base.applying(.font(font)), .view)
        case "foregroundStyle":
            guard let value = try optionalValue(arguments, label: nil, context: &context),
                case .color(let color) = value
            else {
                throw invalid(call, reason: "foregroundStyle requires a color.")
            }
            return .node(base.applying(.foregroundStyle(color)), .view)
        case "frame":
            let frame = try evaluateFrame(arguments, call: call, context: &context)
            return .node(base.applying(.frame(frame)), .view)
        case "padding":
            let padding = try evaluatePadding(arguments, call: call, context: &context)
            return .node(base.applying(padding), .view)
        case "background", "overlay":
            let background: ScriptBackground
            if let value = try optionalValue(arguments, label: nil, context: &context) {
                background = try backgroundValue(value, call: call)
            } else if let closure = call.trailingClosure {
                let values = try compileStatements(closure.statements, context: &context)
                guard values.count == 1, case .node(let node, _) = values[0] else {
                    throw invalid(call, reason: "The trailing builder must produce one view.")
                }
                background = .node(node)
            } else {
                throw missing(call, label: "background content", API: name)
            }
            return .node(
                base.applying(
                    name == "background" ? .background(background) : .overlay(background)), .view)
        case "clipShape":
            guard let value = try optionalValue(arguments, label: nil, context: &context),
                let shape = shapeValue(value)
            else {
                throw invalid(call, reason: "clipShape requires a shape.")
            }
            return .node(base.applying(.clipShape(shape)), .view)
        case "opacity":
            let amount = try requiredNumber(
                arguments, label: nil, API: name, call: call, context: &context)
            try validate(
                amount >= 0 && amount <= 1, call: call, reason: "opacity must be between 0 and 1.")
            return .node(base.applying(.opacity(amount)), .view)
        case "offset":
            let x = try optionalNumber(arguments, label: "x", context: &context) ?? 0
            let y = try optionalNumber(arguments, label: "y", context: &context) ?? 0
            return .node(base.applying(.offset(x: x, y: y)), .view)
        case "rotationEffect":
            guard let argument = arguments.first else {
                throw missing(call, label: "angle", API: name)
            }
            let value = try evaluate(argument.expression, context: &context)
            guard case .number(let degrees) = value else {
                throw invalid(call, reason: "rotationEffect requires .degrees(number).")
            }
            return .node(base.applying(.rotationEffect(degrees: degrees)), .view)
        case "shadow":
            let color =
                try optionalColor(arguments, label: "color", context: &context) ?? .named(.black)
            let radius = try optionalNumber(arguments, label: "radius", context: &context) ?? 0
            try validate(radius >= 0, call: call, reason: "Shadow radius must be non-negative.")
            let x = try optionalNumber(arguments, label: "x", context: &context) ?? 0
            let y = try optionalNumber(arguments, label: "y", context: &context) ?? 0
            return .node(base.applying(.shadow(color: color, radius: radius, x: x, y: y)), .view)
        case "lineLimit":
            let limit = try requiredInt(
                arguments, label: nil, API: name, call: call, context: &context)
            try validate(limit >= 0, call: call, reason: "lineLimit must be non-negative.")
            return .node(base.applying(.lineLimit(limit)), .view)
        case "multilineTextAlignment":
            guard let expression = arguments.first?.expression,
                let member = expression.as(MemberAccessExprSyntax.self), member.base == nil,
                let alignment = ScriptTextAlignment(rawValue: functionName(expression))
            else {
                throw invalid(
                    call, reason: "multilineTextAlignment requires a supported alignment.")
            }
            return .node(base.applying(.multilineTextAlignment(alignment)), .view)
        case "tracking":
            let value = try requiredNumber(
                arguments, label: nil, API: name, call: call, context: &context)
            return .node(base.applying(.tracking(value)), .view)
        case "monospacedDigit":
            try rejectArguments(arguments, API: name, call: call)
            return .node(base.applying(.monospacedDigit), .view)
        case "resizable":
            guard category == .image, base.modifiers.isEmpty else {
                throw invalidModifier(call, name: name)
            }
            try rejectArguments(arguments, API: name, call: call)
            return .node(base.applying(.resizable), .image)
        case "scaledToFill", "scaledToFit":
            guard category == .image else { throw invalidModifier(call, name: name) }
            try rejectArguments(arguments, API: name, call: call)
            return .node(
                base.applying(name == "scaledToFill" ? .scaledToFill : .scaledToFit), .view)
        case "fill":
            guard category == .shape else { throw invalidModifier(call, name: name) }
            let color = try requiredColor(
                arguments, label: nil, API: name, call: call, context: &context)
            return .node(base.applying(.fill(color)), .view)
        case "stroke":
            guard category == .shape else { throw invalidModifier(call, name: name) }
            let color = try requiredColor(
                arguments, label: nil, API: name, call: call, context: &context)
            let lineWidth =
                try optionalNumber(arguments, label: "lineWidth", context: &context) ?? 1
            try validate(lineWidth >= 0, call: call, reason: "Stroke width must be non-negative.")
            return .node(base.applying(.stroke(color: color, lineWidth: lineWidth)), .view)
        default:
            throw .unsupportedModifier(name: name, location: location(of: call))
        }
    }

    fileprivate func evaluateColor(
        _ arguments: [LabeledExprSyntax],
        call: FunctionCallExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> Value {
        if let hex = arguments.first(where: { $0.label?.text == "hex" }) {
            let value = try evaluate(hex.expression, context: &context)
            guard case .string(let string) = value, isValidHex(string) else {
                throw invalid(hex, reason: "hex must be a six or eight digit hexadecimal color.")
            }
            return .color(.hex(string))
        }
        let red = try requiredNumber(
            arguments, label: "red", API: "Color", call: call, context: &context)
        let green = try requiredNumber(
            arguments, label: "green", API: "Color", call: call, context: &context)
        let blue = try requiredNumber(
            arguments, label: "blue", API: "Color", call: call, context: &context)
        let opacity = try optionalNumber(arguments, label: "opacity", context: &context) ?? 1
        try validate(
            (0...1).contains(red) && (0...1).contains(green) && (0...1).contains(blue)
                && (0...1).contains(opacity), call: call,
            reason: "RGB and opacity values must be between 0 and 1.")
        return .color(.rgb(red: red, green: green, blue: blue, opacity: opacity))
    }

    fileprivate func evaluateGradient(
        _ arguments: [LabeledExprSyntax],
        call: FunctionCallExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> Value {
        guard let colorsArgument = arguments.first(where: { $0.label?.text == "colors" }) else {
            throw missing(call, label: "colors", API: "LinearGradient")
        }
        let colorsValue = try evaluate(colorsArgument.expression, context: &context)
        guard case .array(let values) = colorsValue else {
            throw invalid(colorsArgument, reason: "colors must be an array of colors.")
        }
        var colors: [ScriptColor] = []
        for value in values {
            guard case .color(let color) = value else {
                throw invalid(colorsArgument, reason: "colors must contain only colors.")
            }
            colors.append(color)
        }
        guard !colors.isEmpty else {
            throw invalid(colorsArgument, reason: "colors cannot be empty.")
        }
        guard let startArgument = arguments.first(where: { $0.label?.text == "startPoint" }),
            let endArgument = arguments.first(where: { $0.label?.text == "endPoint" })
        else {
            throw missing(call, label: "startPoint/endPoint", API: "LinearGradient")
        }
        guard let startMember = startArgument.expression.as(MemberAccessExprSyntax.self),
            startMember.base == nil,
            let endMember = endArgument.expression.as(MemberAccessExprSyntax.self),
            endMember.base == nil,
            let start = ScriptUnitPoint(rawValue: functionName(startArgument.expression)),
            let end = ScriptUnitPoint(rawValue: functionName(endArgument.expression))
        else {
            throw invalid(call, reason: "LinearGradient points must be named UnitPoints.")
        }
        return .gradient(ScriptLinearGradient(colors: colors, startPoint: start, endPoint: end))
    }

    fileprivate func evaluateForEach(
        _ arguments: [LabeledExprSyntax],
        call: FunctionCallExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> Value {
        guard arguments.count == 1, let closure = call.trailingClosure else {
            throw invalid(
                call, reason: "ForEach supports one range argument and one trailing closure.")
        }
        let rangeValue = try evaluate(arguments[0].expression, context: &context)
        guard case .range(let range) = rangeValue else {
            throw invalidRange(call)
        }
        let distance = range.upperBound.subtractingReportingOverflow(range.lowerBound)
        guard !distance.overflow,
            distance.partialValue <= context.profile.maxIterations - context.iterations
        else {
            throw .budgetExceeded(
                kind: "iteration", limit: context.profile.maxIterations,
                location: location(of: call))
        }
        guard let parameterName = closureParameterName(closure) else {
            throw invalid(call, reason: "ForEach requires one named closure parameter.")
        }
        let previous = context.variables[parameterName]
        defer { context.variables[parameterName] = previous }
        var nodes: [Value] = []
        for index in range {
            context.iterations += 1
            context.variables[parameterName] = .integer(index)
            nodes.append(contentsOf: try compileStatements(closure.statements, context: &context))
        }
        return .array(nodes)
    }

    fileprivate func evaluateSequence(
        _ sequence: SequenceExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> Value {
        let elements = Array(sequence.elements)
        guard elements.count >= 3, elements.count % 2 == 1 else {
            throw unsupported(sequence, name: "expression sequence")
        }
        let precedence = ["..<": 0, "...": 0, "+": 1, "-": 1, "*": 2, "/": 2]
        var values = [try evaluate(elements[0], context: &context)]
        var operators: [String] = []
        for index in stride(from: 1, to: elements.count, by: 2) {
            let operation = elements[index].trimmedDescription
            guard let rank = precedence[operation] else {
                throw unsupported(sequence, name: operation)
            }
            while let previous = operators.last, precedence[previous]! >= rank {
                let rhs = values.removeLast()
                let lhs = values.removeLast()
                values.append(
                    try arithmetic(
                        left: lhs, operation: operators.removeLast(), right: rhs, syntax: sequence))
            }
            operators.append(operation)
            values.append(try evaluate(elements[index + 1], context: &context))
        }
        while !operators.isEmpty {
            let rhs = values.removeLast()
            let lhs = values.removeLast()
            values.append(
                try arithmetic(
                    left: lhs, operation: operators.removeLast(), right: rhs, syntax: sequence))
        }
        return values[0]
    }

    fileprivate func evaluatePrefix(
        _ prefix: PrefixOperatorExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> Value {
        let operation = prefix.operator.text
        let value = try evaluate(prefix.expression, context: &context)
        guard operation == "-" else {
            throw unsupported(prefix, name: "prefix operator \(operation)")
        }
        if case .integer(let value) = value {
            guard value != Int.min else { throw .nonFiniteResult(location: location(of: prefix)) }
            return .integer(-value)
        }
        if case .number(let value) = value { return .number(-value) }
        throw invalid(prefix, reason: "Unary minus requires a number.")
    }

    fileprivate func arithmetic(
        left: Value,
        operation: String,
        right: Value,
        syntax: some SyntaxProtocol
    ) throws(ScriptError) -> Value {
        if operation == "..<" || operation == "..." {
            guard let lower = integer(left), let upper = integer(right), lower <= upper else {
                throw invalidRange(syntax)
            }
            guard operation != "..." || upper < Int.max else { throw invalidRange(syntax) }
            return .range(operation == "..<" ? lower..<upper : lower..<(upper + 1))
        }
        if case .integer(let lhs) = left, case .integer(let rhs) = right {
            let result: (partialValue: Int, overflow: Bool)
            switch operation {
            case "+": result = lhs.addingReportingOverflow(rhs)
            case "-": result = lhs.subtractingReportingOverflow(rhs)
            case "*": result = lhs.multipliedReportingOverflow(by: rhs)
            case "/":
                guard rhs != 0 else { throw .divisionByZero(location: location(of: syntax)) }
                result = lhs.dividedReportingOverflow(by: rhs)
            default: throw unsupported(syntax, name: "operator \(operation)")
            }
            guard !result.overflow else {
                throw invalid(syntax, reason: "Integer arithmetic overflow.")
            }
            return .integer(result.partialValue)
        }
        guard let lhs = number(left), let rhs = number(right) else {
            throw invalid(syntax, reason: "Arithmetic requires numeric operands.")
        }
        let result: Double
        switch operation {
        case "+": result = lhs + rhs
        case "-": result = lhs - rhs
        case "*": result = lhs * rhs
        case "/":
            guard rhs != 0 else { throw .divisionByZero(location: location(of: syntax)) }
            result = lhs / rhs
        default:
            throw unsupported(syntax, name: "operator \(operation)")
        }
        guard result.isFinite else { throw .nonFiniteResult(location: location(of: syntax)) }
        return .number(result)
    }

    fileprivate func builderChildren(
        _ call: FunctionCallExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> [ScriptNode] {
        guard let closure = call.trailingClosure else {
            throw missing(call, label: "trailing builder", API: functionName(call.calledExpression))
        }
        let values = try compileStatements(closure.statements, context: &context)
        var nodes: [ScriptNode] = []
        for value in values {
            guard case .node(let node, _) = try viewValue(value, syntax: call, context: &context)
            else {
                throw invalid(call, reason: "A builder child must produce a view.")
            }
            nodes.append(node)
        }
        return nodes
    }

    fileprivate func evaluateFrame(
        _ arguments: [LabeledExprSyntax],
        call: FunctionCallExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> ScriptFrame {
        let labels = Set(arguments.compactMap { $0.label?.text })
        let fixedLabels: Set<String> = ["width", "height", "alignment"]
        let flexibleLabels: Set<String> = [
            "minWidth", "idealWidth", "maxWidth", "minHeight", "idealHeight", "maxHeight",
            "alignment",
        ]
        guard labels.subtracting(fixedLabels).isEmpty || labels.subtracting(flexibleLabels).isEmpty
        else {
            throw invalid(call, reason: "frame arguments mix fixed and flexible overloads.")
        }
        let alignment = try optionalAlignment(
            arguments, label: "alignment", default: .center, context: &context)
        if labels.contains(where: {
            $0.hasPrefix("min") || $0.hasPrefix("ideal") || $0.hasPrefix("max")
        }) {
            let minWidth = try optionalNumber(arguments, label: "minWidth", context: &context)
            let idealWidth = try optionalNumber(arguments, label: "idealWidth", context: &context)
            let maxWidth = try optionalDimension(arguments, label: "maxWidth", context: &context)
            let minHeight = try optionalNumber(arguments, label: "minHeight", context: &context)
            let idealHeight = try optionalNumber(arguments, label: "idealHeight", context: &context)
            let maxHeight = try optionalDimension(arguments, label: "maxHeight", context: &context)
            try validateFrame(
                min: minWidth, ideal: idealWidth, max: maxWidth, call: call, axis: "width")
            try validateFrame(
                min: minHeight, ideal: idealHeight, max: maxHeight, call: call, axis: "height")
            return .flexible(
                minWidth: minWidth.map(ScriptDimension.value),
                idealWidth: idealWidth.map(ScriptDimension.value),
                maxWidth: maxWidth,
                minHeight: minHeight.map(ScriptDimension.value),
                idealHeight: idealHeight.map(ScriptDimension.value),
                maxHeight: maxHeight,
                alignment: alignment
            )
        }
        let width = try optionalNumber(arguments, label: "width", context: &context)
        let height = try optionalNumber(arguments, label: "height", context: &context)
        try validate(
            width == nil || width! >= 0, call: call, reason: "frame width must be non-negative.")
        try validate(
            height == nil || height! >= 0, call: call, reason: "frame height must be non-negative.")
        return .fixed(width: width, height: height, alignment: alignment)
    }

    fileprivate func evaluatePadding(
        _ arguments: [LabeledExprSyntax],
        call: FunctionCallExprSyntax,
        context: inout Context
    ) throws(ScriptError) -> ScriptModifier {
        guard arguments.count <= 2 else {
            throw invalid(call, reason: "padding accepts one edge and one amount.")
        }
        let edge: ScriptEdge
        let amount: Double?
        if let first = arguments.first, first.label == nil {
            if let value = edgeValue(first.expression) {
                edge = value
                if let argument = arguments.dropFirst().first {
                    amount = try numberValue(argument.expression, context: &context)
                } else {
                    amount = nil
                }
            } else {
                guard arguments.count == 1 else {
                    throw invalid(
                        call, reason: "Two padding arguments require an edge followed by an amount."
                    )
                }
                let firstValue = try evaluate(first.expression, context: &context)
                if case .edge(let value) = firstValue {
                    edge = value
                    if let argument = arguments.dropFirst().first {
                        amount = try numberValue(argument.expression, context: &context)
                    } else {
                        amount = nil
                    }
                } else {
                    edge = .all
                    amount = try numberValue(first.expression, context: &context)
                }
            }
        } else {
            edge = .all
            if let argument = arguments.first {
                amount = try numberValue(argument.expression, context: &context)
            } else {
                amount = nil
            }
        }
        if let amount {
            try validate(amount >= 0, call: call, reason: "padding must be non-negative.")
        }
        return .padding(edge: edge, amount: amount)
    }

    fileprivate func backgroundValue(_ value: Value, call: FunctionCallExprSyntax)
        throws(ScriptError) -> ScriptBackground
    {
        switch value {
        case .color(let color): return .color(color)
        case .gradient(let gradient): return .linearGradient(gradient)
        case .node(let node, _): return .node(node)
        default:
            throw invalid(
                call, reason: "background and overlay require a color, gradient, or view.")
        }
    }

    fileprivate func node(
        _ kind: ScriptNodeKind,
        category: Category,
        syntax: some SyntaxProtocol,
        context: inout Context
    ) throws(ScriptError) -> Value {
        try context.countNode(syntax)
        return .node(ScriptNode(kind: kind), category)
    }

    fileprivate func viewValue(_ value: Value, syntax: some SyntaxProtocol, context: inout Context)
        throws(ScriptError) -> Value
    {
        switch value {
        case .node: return value
        case .color(let color):
            return try node(.color(color), category: .view, syntax: syntax, context: &context)
        case .gradient(let gradient):
            return try node(
                .linearGradient(gradient), category: .view, syntax: syntax, context: &context)
        default: throw invalid(syntax, reason: "Expected a view expression.")
        }
    }

    fileprivate func optionalValue(
        _ arguments: [LabeledExprSyntax],
        label: String?,
        context: inout Context
    ) throws(ScriptError) -> Value? {
        guard
            let argument = arguments.first(where: { $0.label?.text == label })
                ?? (label == nil ? arguments.first(where: { $0.label == nil }) : nil)
        else {
            return nil
        }
        return try evaluate(argument.expression, context: &context)
    }

    fileprivate func requiredValue(
        _ arguments: [LabeledExprSyntax],
        label: String?,
        API: String,
        call: some SyntaxProtocol,
        context: inout Context
    ) throws(ScriptError) -> Value {
        guard let value = try optionalValue(arguments, label: label, context: &context) else {
            throw missing(call, label: label ?? "value", API: API)
        }
        return value
    }

    fileprivate func optionalNumber(
        _ arguments: [LabeledExprSyntax],
        label: String?,
        context: inout Context
    ) throws(ScriptError) -> Double? {
        guard let value = try optionalValue(arguments, label: label, context: &context) else {
            return nil
        }
        guard let number = number(value) else {
            throw invalid(arguments[0], reason: "Expected a finite number.")
        }
        return number
    }

    fileprivate func optionalDimension(
        _ arguments: [LabeledExprSyntax],
        label: String?,
        context: inout Context
    ) throws(ScriptError) -> ScriptDimension? {
        guard let value = try optionalValue(arguments, label: label, context: &context) else {
            return nil
        }
        switch value {
        case .dimension(let dimension): return dimension
        case .number(let number) where number.isFinite: return .value(number)
        case .integer(let number): return .value(Double(number))
        default: throw invalid(arguments[0], reason: "Expected a finite number or infinity.")
        }
    }

    fileprivate func optionalColor(
        _ arguments: [LabeledExprSyntax],
        label: String?,
        context: inout Context
    ) throws(ScriptError) -> ScriptColor? {
        guard let value = try optionalValue(arguments, label: label, context: &context) else {
            return nil
        }
        guard case .color(let color) = value else {
            throw invalid(arguments[0], reason: "Expected a color.")
        }
        return color
    }

    fileprivate func requiredColor(
        _ arguments: [LabeledExprSyntax],
        label: String?,
        API: String,
        call: some SyntaxProtocol,
        context: inout Context
    ) throws(ScriptError) -> ScriptColor {
        guard let color = try optionalColor(arguments, label: label, context: &context) else {
            throw missing(call, label: label ?? "color", API: API)
        }
        return color
    }

    fileprivate func requiredNumber(
        _ arguments: [LabeledExprSyntax],
        label: String?,
        API: String,
        call: some SyntaxProtocol,
        context: inout Context
    ) throws(ScriptError) -> Double {
        guard let value = try optionalNumber(arguments, label: label, context: &context) else {
            throw missing(call, label: label ?? "value", API: API)
        }
        return value
    }

    fileprivate func requiredInt(
        _ arguments: [LabeledExprSyntax],
        label: String?,
        API: String,
        call: some SyntaxProtocol,
        context: inout Context
    ) throws(ScriptError) -> Int {
        let value = try requiredValue(
            arguments, label: label, API: API, call: call, context: &context)
        guard let integer = integer(value) else {
            throw invalid(call, reason: "Expected an integer.")
        }
        return integer
    }

    fileprivate func optionalAlignment(
        _ arguments: [LabeledExprSyntax],
        label: String,
        default defaultValue: ScriptAlignment,
        context: inout Context
    ) throws(ScriptError) -> ScriptAlignment {
        guard let value = try optionalValue(arguments, label: label, context: &context) else {
            return defaultValue
        }
        guard case .alignment(let alignment) = value else {
            throw invalid(arguments[0], reason: "Expected a horizontal alignment.")
        }
        return alignment
    }

    fileprivate func optionalVerticalAlignment(
        _ arguments: [LabeledExprSyntax],
        label: String,
        default defaultValue: ScriptVerticalAlignment,
        context: inout Context
    ) throws(ScriptError) -> ScriptVerticalAlignment {
        guard let value = try optionalValue(arguments, label: label, context: &context) else {
            return defaultValue
        }
        if case .verticalAlignment(let alignment) = value { return alignment }
        if case .alignment(let alignment) = value {
            switch alignment {
            case .top: return .top
            case .bottom: return .bottom
            case .center: return .center
            default: throw invalid(arguments[0], reason: "HStack requires a vertical alignment.")
            }
        }
        throw invalid(arguments[0], reason: "Expected a vertical alignment.")
    }

    fileprivate func numberValue(_ expression: ExprSyntax, context: inout Context)
        throws(ScriptError) -> Double
    {
        guard let value = number(try evaluate(expression, context: &context)) else {
            throw invalid(expression, reason: "Expected a finite number.")
        }
        return value
    }

    fileprivate func validateCall(_ call: FunctionCallExprSyntax, name: String) throws(ScriptError)
    {
        let allowed: Set<String>
        var maxUnlabeled = 0
        switch name {
        case "Text", "font", "foregroundStyle", "clipShape", "opacity", "rotationEffect",
            "lineLimit", "multilineTextAlignment", "tracking", "fill", "degrees", "ForEach":
            allowed = [""]
            maxUnlabeled = 1
        case "Image": allowed = ["systemName", "asset"]
        case "VStack", "HStack": allowed = ["alignment", "spacing"]
        case "ZStack": allowed = ["alignment"]
        case "Spacer": allowed = ["minLength"]
        case "RoundedRectangle": allowed = ["cornerRadius"]
        case "Color":
            allowed =
                call.arguments.contains(where: { $0.label?.text == "hex" })
                ? ["hex"] : ["red", "green", "blue", "opacity"]
        case "LinearGradient": allowed = ["colors", "startPoint", "endPoint"]
        case "system": allowed = ["size", "weight", "design"]
        case "frame":
            allowed = [
                "width", "height", "minWidth", "idealWidth", "maxWidth", "minHeight", "idealHeight",
                "maxHeight", "alignment",
            ]
        case "padding":
            allowed = [""]
            maxUnlabeled = 2
        case "background", "overlay":
            allowed = [""]
            maxUnlabeled = 1
        case "offset": allowed = ["x", "y"]
        case "shadow": allowed = ["color", "radius", "x", "y"]
        case "stroke":
            allowed = ["", "lineWidth"]
            maxUnlabeled = 1
        case "Divider", "Rectangle", "Circle", "Ellipse", "Capsule", "resizable",
            "scaledToFill", "scaledToFit", "monospacedDigit":
            allowed = []
        default: return
        }
        var seen = Set<String>()
        var unlabeled = 0
        for argument in call.arguments {
            let label = argument.label?.text ?? ""
            guard allowed.contains(label) else {
                throw .unsupportedArgumentLabel(
                    label: label, API: name, location: location(of: argument))
            }
            if label.isEmpty {
                unlabeled += 1
                guard unlabeled <= maxUnlabeled else {
                    throw invalid(call, reason: "Too many positional arguments.")
                }
            } else {
                guard seen.insert(label).inserted else {
                    throw invalid(call, reason: "Duplicate argument label \(label).")
                }
            }
        }
        if name == "Image", call.arguments.count != 1 {
            throw invalid(call, reason: "Image requires exactly one source.")
        }
        if name == "shadow", !seen.contains("radius") {
            throw missing(call, label: "radius", API: name)
        }
        guard call.additionalTrailingClosures.isEmpty else {
            throw unsupported(call, name: "multiple trailing closures")
        }
        if let closure = call.trailingClosure {
            guard ["VStack", "HStack", "ZStack", "ForEach", "background", "overlay"].contains(name)
            else {
                throw unsupported(call, name: "trailing closure for \(name)")
            }
            if name != "ForEach", closure.signature != nil {
                throw unsupported(closure, name: "builder parameters")
            }
            if ["background", "overlay"].contains(name), !call.arguments.isEmpty {
                throw invalid(call, reason: "Provide either an argument or a trailing builder.")
            }
        }
    }

    fileprivate func rejectArguments(
        _ arguments: [LabeledExprSyntax],
        API: String,
        call: some SyntaxProtocol
    ) throws(ScriptError) {
        guard arguments.isEmpty else {
            throw unsupported(call, name: "arguments for \(API)")
        }
    }

    fileprivate func validateFrame(
        min: Double?,
        ideal: Double?,
        max: ScriptDimension?,
        call: some SyntaxProtocol,
        axis: String
    ) throws(ScriptError) {
        if let min, min < 0 {
            throw invalid(call, reason: "frame \(axis) minimum must be non-negative.")
        }
        if let ideal, ideal < 0 {
            throw invalid(call, reason: "frame \(axis) ideal must be non-negative.")
        }
        if let max = max, case .value(let max) = max, max < 0 {
            throw invalid(call, reason: "frame \(axis) maximum must be non-negative.")
        }
        if let min, let ideal, ideal < min {
            throw invalid(call, reason: "frame \(axis) ideal is below minimum.")
        }
        if let ideal, let max = max, case .value(let max) = max, ideal > max {
            throw invalid(call, reason: "frame \(axis) ideal exceeds maximum.")
        }
        if let min, let max = max, case .value(let max) = max, min > max {
            throw invalid(call, reason: "frame \(axis) minimum exceeds maximum.")
        }
    }

    fileprivate func validate(_ condition: Bool, call: some SyntaxProtocol, reason: String)
        throws(ScriptError)
    {
        guard condition else { throw invalid(call, reason: reason) }
    }

    fileprivate func functionName(_ expression: ExprSyntax) -> String {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text
        }
        if let member = expression.as(MemberAccessExprSyntax.self) {
            return member.declName.baseName.text
        }
        return expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate func closureParameterName(_ closure: ClosureExprSyntax) -> String? {
        guard let signature = closure.signature,
            signature.attributes.isEmpty, signature.capture == nil,
            signature.effectSpecifiers == nil, signature.returnClause == nil
        else { return nil }
        switch signature.parameterClause {
        case .simpleInput(let parameters):
            guard parameters.count == 1, let parameter = parameters.first,
                case .identifier = parameter.name.tokenKind
            else { return nil }
            return parameter.name.text
        case .parameterClause, nil:
            return nil
        }
    }

    fileprivate func isValidHex(_ string: String) -> Bool {
        let value = string.hasPrefix("#") ? String(string.dropFirst()) : string
        guard value.count == 6 || value.count == 8 else { return false }
        return UInt64(value, radix: 16) != nil
    }

    fileprivate func number(_ value: Value) -> Double? {
        switch value {
        case .integer(let value): return Double(value)
        case .number(let value): return value.isFinite ? value : nil
        default: return nil
        }
    }

    fileprivate func shapeValue(_ value: Value) -> ScriptShape? {
        switch value {
        case .shape(let shape): return shape
        case .node(let node, .shape):
            guard case .shape(let shape) = node.kind else { return nil }
            return shape
        default: return nil
        }
    }

    fileprivate func edgeValue(_ expression: ExprSyntax) -> ScriptEdge? {
        guard let member = expression.as(MemberAccessExprSyntax.self), member.base == nil else {
            return nil
        }
        return ScriptEdge(rawValue: member.declName.baseName.text)
    }

    fileprivate func integer(_ value: Value) -> Int? {
        switch value {
        case .integer(let value): return value
        case .number(let value): return Int(exactly: value)
        default: return nil
        }
    }

    fileprivate func location(of syntax: some SyntaxProtocol) -> ScriptSourceLocation {
        ScriptSourceLocation(utf8Offset: syntax.positionAfterSkippingLeadingTrivia.utf8Offset)
    }

    fileprivate func invalid(_ syntax: some SyntaxProtocol, reason: String) -> ScriptError {
        .invalidValue(reason: reason, location: location(of: syntax))
    }

    fileprivate func unsupported(_ syntax: some SyntaxProtocol, name: String) -> ScriptError {
        .unsupportedSyntax(name: name, location: location(of: syntax))
    }

    fileprivate func unknown(_ syntax: some SyntaxProtocol, name: String) -> ScriptError {
        .unknownIdentifier(name: name, location: location(of: syntax))
    }

    fileprivate func missing(_ syntax: some SyntaxProtocol, label: String, API: String)
        -> ScriptError
    {
        .missingArgument(label: label, API: API, location: location(of: syntax))
    }

    fileprivate func invalidModifier(_ syntax: some SyntaxProtocol, name: String) -> ScriptError {
        .invalidModifierOrder(name: name, location: location(of: syntax))
    }

    fileprivate func invalidRange(_ syntax: some SyntaxProtocol) -> ScriptError {
        .invalidRange(location: location(of: syntax))
    }
}

extension SyntaxProtocol {
    fileprivate var syntaxNodeTypeName: String {
        String(describing: type(of: self))
    }
}
