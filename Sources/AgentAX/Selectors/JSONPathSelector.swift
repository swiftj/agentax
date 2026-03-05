import Foundation

// MARK: - Types

/// Comparison operators for filter expressions.
public enum ComparisonOp: Sendable {
    case equal
    case notEqual
}

/// Values that can appear on the right side of a filter comparison.
public enum FilterValue: Sendable, Equatable {
    case string(String)
    case bool(Bool)
    case number(Double)
}

/// A filter expression within a `[?(...)]` bracket.
public indirect enum FilterExpression: Sendable {
    case comparison(property: String, op: ComparisonOp, value: FilterValue)
    case exists(property: String)
    case and(FilterExpression, FilterExpression)
    case or(FilterExpression, FilterExpression)
}

/// A single segment of a parsed JSONPath.
public enum PathSegment: Sendable {
    case root                           // $
    case child(String)                  // .name
    case recursiveDescent               // ..
    case filter(FilterExpression)       // [?(...)]
}

// MARK: - JSONPathSelector

/// Minimal JSONPath query engine for filtering UIElements in the captured AX tree.
///
/// Supported syntax:
/// - `$` root
/// - `.child` child access
/// - `..` recursive descent
/// - `[?(@.prop == 'value')]` filter expressions with ==, !=, &&, ||, existence
public struct JSONPathSelector: Sendable {
    public let rawPath: String
    public let segments: [PathSegment]

    /// Parse a JSONPath string into segments.
    public init(_ path: String) throws {
        self.rawPath = path
        self.segments = try JSONPathParser.parse(path)
    }

    /// Execute the query against a `SystemState`, returning matching `UIElement`s.
    public func execute(on state: SystemState) -> [UIElement] {
        // Start with a sentinel: the execution context is the SystemState itself.
        // We process segments left-to-right, maintaining a mixed bag of
        // "current nodes" which can be ProcessInfo or UIElement.
        var context: ExecutionContext = .systemState(state)

        for segment in segments {
            context = apply(segment, to: context)
        }

        return context.elements
    }

    /// Execute the query against a flat list of UIElements (no SystemState wrapper).
    public func execute(on elements: [UIElement]) -> [UIElement] {
        var context: ExecutionContext = .elements(elements)

        for segment in segments {
            context = apply(segment, to: context)
        }

        return context.elements
    }

    // MARK: - Execution internals

    private enum ExecutionContext: Sendable {
        case systemState(SystemState)
        case processes([ProcessInfo])
        case elements([UIElement])

        var elements: [UIElement] {
            switch self {
            case .systemState(let state):
                return state.processes.flatMap { $0.windows }
            case .processes(let procs):
                return procs.flatMap { $0.windows }
            case .elements(let elems):
                return elems
            }
        }
    }

    private func apply(_ segment: PathSegment, to context: ExecutionContext) -> ExecutionContext {
        switch segment {
        case .root:
            return context

        case .child(let name):
            return applyChild(name, to: context)

        case .recursiveDescent:
            let elems = context.elements
            return .elements(collectAllDescendants(from: elems))

        case .filter(let expr):
            switch context {
            case .processes(let procs):
                let filtered = procs.filter { evaluateOnProcess(expr, process: $0) }
                return .processes(filtered)
            case .elements(let elems):
                let filtered = elems.filter { evaluateOnElement(expr, element: $0) }
                return .elements(filtered)
            case .systemState:
                return context
            }
        }
    }

    private func applyChild(_ name: String, to context: ExecutionContext) -> ExecutionContext {
        switch name {
        case "processes":
            switch context {
            case .systemState(let state):
                return .processes(state.processes)
            default:
                return .elements([])
            }

        case "windows":
            switch context {
            case .processes(let procs):
                return .elements(procs.flatMap { $0.windows })
            case .elements(let elems):
                // UIElements don't have "windows", but treat as children access
                return .elements(elems.flatMap { $0.children })
            default:
                return .elements([])
            }

        case "children":
            let elems = context.elements
            return .elements(elems.flatMap { $0.children })

        default:
            return .elements([])
        }
    }

    /// Recursively collect all descendants (including the roots themselves).
    private func collectAllDescendants(from elements: [UIElement]) -> [UIElement] {
        var result: [UIElement] = []
        var stack = elements
        while let current = stack.popLast() {
            result.append(current)
            // Push children in reverse so we process them in order
            stack.append(contentsOf: current.children.reversed())
        }
        return result
    }

    // MARK: - Filter evaluation on UIElement

    private func evaluateOnElement(_ expr: FilterExpression, element: UIElement) -> Bool {
        switch expr {
        case .comparison(let property, let op, let value):
            guard let propValue = resolveProperty(property, on: element) else {
                return op == .notEqual
            }
            let matches = propValue == value
            return op == .equal ? matches : !matches

        case .exists(let property):
            return resolveProperty(property, on: element) != nil

        case .and(let lhs, let rhs):
            return evaluateOnElement(lhs, element: element) && evaluateOnElement(rhs, element: element)

        case .or(let lhs, let rhs):
            return evaluateOnElement(lhs, element: element) || evaluateOnElement(rhs, element: element)
        }
    }

    /// Resolve a dotted property path on a UIElement to a FilterValue.
    private func resolveProperty(_ property: String, on element: UIElement) -> FilterValue? {
        // Handle customContent.keyName
        if property.hasPrefix("customContent.") {
            let key = String(property.dropFirst("customContent.".count))
            if let val = element.customContent[key] {
                return .string(val)
            }
            return nil
        }

        switch property {
        case "role":
            return .string(element.role)
        case "title":
            return element.title.map { .string($0) }
        case "value":
            return element.value.map { .string($0) }
        case "identifier":
            return element.identifier.map { .string($0) }
        case "label":
            return element.label.map { .string($0) }
        case "roleDescription":
            return element.roleDescription.map { .string($0) }
        case "enabled", "isEnabled":
            return .bool(element.isEnabled)
        case "focused", "isFocused":
            return .bool(element.isFocused)
        case "depth":
            return .number(Double(element.depth))
        default:
            return nil
        }
    }

    // MARK: - Filter evaluation on ProcessInfo

    private func evaluateOnProcess(_ expr: FilterExpression, process: ProcessInfo) -> Bool {
        switch expr {
        case .comparison(let property, let op, let value):
            guard let propValue = resolveProcessProperty(property, on: process) else {
                return op == .notEqual
            }
            let matches = propValue == value
            return op == .equal ? matches : !matches

        case .exists(let property):
            return resolveProcessProperty(property, on: process) != nil

        case .and(let lhs, let rhs):
            return evaluateOnProcess(lhs, process: process) && evaluateOnProcess(rhs, process: process)

        case .or(let lhs, let rhs):
            return evaluateOnProcess(lhs, process: process) || evaluateOnProcess(rhs, process: process)
        }
    }

    private func resolveProcessProperty(_ property: String, on process: ProcessInfo) -> FilterValue? {
        switch property {
        case "name":
            return .string(process.name)
        case "pid":
            return .number(Double(process.pid))
        case "bundleIdentifier":
            return process.bundleIdentifier.map { .string($0) }
        case "isActive", "active":
            return .bool(process.isActive)
        case "isHidden", "hidden":
            return .bool(process.isHidden)
        default:
            return nil
        }
    }
}

// MARK: - Parser

/// Tokenizer and parser for JSONPath expressions.
enum JSONPathParser {

    enum Token: Sendable, Equatable {
        case dollar           // $
        case dot              // .
        case doubleDot        // ..
        case identifier(String)
        case filterOpen       // [?(
        case filterClose      // )]
        case at               // @
        case eq               // ==
        case neq              // !=
        case and              // &&
        case or               // ||
        case singleQuotedString(String)
        case boolTrue
        case boolFalse
        case number(Double)
    }

    static func parse(_ path: String) throws -> [PathSegment] {
        let tokens = try tokenize(path)
        return try parseTokens(tokens)
    }

    // MARK: - Tokenizer

    static func tokenize(_ path: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(path)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            switch c {
            case "$":
                tokens.append(.dollar)
                i += 1

            case ".":
                if i + 1 < chars.count && chars[i + 1] == "." {
                    tokens.append(.doubleDot)
                    i += 2
                } else {
                    tokens.append(.dot)
                    i += 1
                }

            case "[":
                // Expect [?(
                if i + 2 < chars.count && chars[i + 1] == "?" && chars[i + 2] == "(" {
                    tokens.append(.filterOpen)
                    i += 3
                } else {
                    throw AXError.invalidSelector("Unexpected '[' without '?(' at position \(i)")
                }

            case ")":
                if i + 1 < chars.count && chars[i + 1] == "]" {
                    tokens.append(.filterClose)
                    i += 2
                } else {
                    throw AXError.invalidSelector("Unexpected ')' without ']' at position \(i)")
                }

            case "@":
                tokens.append(.at)
                i += 1

            case "=":
                if i + 1 < chars.count && chars[i + 1] == "=" {
                    tokens.append(.eq)
                    i += 2
                } else {
                    throw AXError.invalidSelector("Single '=' at position \(i), expected '=='")
                }

            case "!":
                if i + 1 < chars.count && chars[i + 1] == "=" {
                    tokens.append(.neq)
                    i += 2
                } else {
                    throw AXError.invalidSelector("Unexpected '!' at position \(i)")
                }

            case "&":
                if i + 1 < chars.count && chars[i + 1] == "&" {
                    tokens.append(.and)
                    i += 2
                } else {
                    throw AXError.invalidSelector("Single '&' at position \(i), expected '&&'")
                }

            case "|":
                if i + 1 < chars.count && chars[i + 1] == "|" {
                    tokens.append(.or)
                    i += 2
                } else {
                    throw AXError.invalidSelector("Single '|' at position \(i), expected '||'")
                }

            case "'":
                // Parse single-quoted string
                i += 1
                var str = ""
                while i < chars.count && chars[i] != "'" {
                    if chars[i] == "\\" && i + 1 < chars.count {
                        i += 1
                        str.append(chars[i])
                    } else {
                        str.append(chars[i])
                    }
                    i += 1
                }
                guard i < chars.count else {
                    throw AXError.invalidSelector("Unterminated string literal")
                }
                i += 1 // skip closing '
                tokens.append(.singleQuotedString(str))

            case " ", "\t", "\n", "\r":
                i += 1

            default:
                // Identifier or keyword (true/false/number)
                if c.isLetter || c == "_" {
                    var ident = String(c)
                    i += 1
                    while i < chars.count && (chars[i].isLetter || chars[i].isNumber || chars[i] == "_") {
                        ident.append(chars[i])
                        i += 1
                    }
                    if ident == "true" {
                        tokens.append(.boolTrue)
                    } else if ident == "false" {
                        tokens.append(.boolFalse)
                    } else {
                        tokens.append(.identifier(ident))
                    }
                } else if c.isNumber || c == "-" {
                    var numStr = String(c)
                    i += 1
                    while i < chars.count && (chars[i].isNumber || chars[i] == ".") {
                        numStr.append(chars[i])
                        i += 1
                    }
                    guard let num = Double(numStr) else {
                        throw AXError.invalidSelector("Invalid number: \(numStr)")
                    }
                    tokens.append(.number(num))
                } else {
                    throw AXError.invalidSelector("Unexpected character '\(c)' at position \(i)")
                }
            }
        }

        return tokens
    }

    // MARK: - Segment parser

    static func parseTokens(_ tokens: [Token]) throws -> [PathSegment] {
        var segments: [PathSegment] = []
        var i = 0

        while i < tokens.count {
            switch tokens[i] {
            case .dollar:
                segments.append(.root)
                i += 1

            case .doubleDot:
                segments.append(.recursiveDescent)
                i += 1
                // If followed by a filter, it will be picked up next iteration.
                // If followed by an identifier, skip the implicit dot.

            case .dot:
                i += 1
                if i < tokens.count, case .identifier(let name) = tokens[i] {
                    segments.append(.child(name))
                    i += 1
                } else if i < tokens.count, case .filterOpen = tokens[i] {
                    // .[ is treated as just the filter (handled below)
                    continue
                }

            case .identifier(let name):
                // Bare identifier after recursive descent
                segments.append(.child(name))
                i += 1

            case .filterOpen:
                i += 1
                let (expr, nextIndex) = try parseFilterExpression(tokens, from: i)
                i = nextIndex
                guard i < tokens.count, case .filterClose = tokens[i] else {
                    throw AXError.invalidSelector("Expected )] to close filter expression")
                }
                i += 1
                segments.append(.filter(expr))

            default:
                throw AXError.invalidSelector("Unexpected token at position \(i)")
            }
        }

        return segments
    }

    // MARK: - Filter expression parser

    /// Parse a filter expression handling OR (lowest precedence), AND, then atoms.
    static func parseFilterExpression(_ tokens: [Token], from index: Int) throws -> (FilterExpression, Int) {
        return try parseOr(tokens, from: index)
    }

    private static func parseOr(_ tokens: [Token], from index: Int) throws -> (FilterExpression, Int) {
        var (lhs, i) = try parseAnd(tokens, from: index)
        while i < tokens.count, case .or = tokens[i] {
            i += 1
            let (rhs, nextI) = try parseAnd(tokens, from: i)
            lhs = .or(lhs, rhs)
            i = nextI
        }
        return (lhs, i)
    }

    private static func parseAnd(_ tokens: [Token], from index: Int) throws -> (FilterExpression, Int) {
        var (lhs, i) = try parseAtom(tokens, from: index)
        while i < tokens.count, case .and = tokens[i] {
            i += 1
            let (rhs, nextI) = try parseAtom(tokens, from: i)
            lhs = .and(lhs, rhs)
            i = nextI
        }
        return (lhs, i)
    }

    private static func parseAtom(_ tokens: [Token], from index: Int) throws -> (FilterExpression, Int) {
        var i = index

        // Expect @ . property
        guard i < tokens.count, case .at = tokens[i] else {
            throw AXError.invalidSelector("Expected '@' in filter expression at position \(i)")
        }
        i += 1

        guard i < tokens.count, case .dot = tokens[i] else {
            throw AXError.invalidSelector("Expected '.' after '@' at position \(i)")
        }
        i += 1

        guard i < tokens.count, case .identifier(var property) = tokens[i] else {
            throw AXError.invalidSelector("Expected property name after '@.' at position \(i)")
        }
        i += 1

        // Consume dotted sub-properties (e.g., customContent.position_x)
        while i + 1 < tokens.count, case .dot = tokens[i], case .identifier(let sub) = tokens[i + 1] {
            property += "." + sub
            i += 2
        }

        // Check if this is a comparison or existence check
        if i < tokens.count {
            switch tokens[i] {
            case .eq:
                i += 1
                let (value, nextI) = try parseValue(tokens, from: i)
                return (.comparison(property: property, op: .equal, value: value), nextI)
            case .neq:
                i += 1
                let (value, nextI) = try parseValue(tokens, from: i)
                return (.comparison(property: property, op: .notEqual, value: value), nextI)
            default:
                // Existence check
                return (.exists(property: property), i)
            }
        }

        // Existence check (at end of tokens)
        return (.exists(property: property), i)
    }

    private static func parseValue(_ tokens: [Token], from index: Int) throws -> (FilterValue, Int) {
        guard index < tokens.count else {
            throw AXError.invalidSelector("Expected value at end of expression")
        }
        switch tokens[index] {
        case .singleQuotedString(let s):
            return (.string(s), index + 1)
        case .boolTrue:
            return (.bool(true), index + 1)
        case .boolFalse:
            return (.bool(false), index + 1)
        case .number(let n):
            return (.number(n), index + 1)
        default:
            throw AXError.invalidSelector("Expected value (string, bool, or number) at position \(index)")
        }
    }
}
