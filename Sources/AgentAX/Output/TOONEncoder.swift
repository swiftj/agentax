import Foundation

/// Token-Optimized Object Notation encoder.
/// Produces an indentation-based format that is 30-60% more token-efficient than JSON.
public struct TOONEncoder: Sendable {
    public init() {}

    // MARK: - Public API

    public func encode(_ state: SystemState) -> String {
        var lines: [String] = []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        lines.append("capturedAt: \(formatter.string(from: state.capturedAt))")
        lines.append("captureTimeMs: \(formatNumber(state.captureTimeMs))")

        if !state.processes.isEmpty {
            lines.append("processes:")
            for process in state.processes {
                let processLines = encodeProcess(process, indent: 1)
                // First line gets "- " prefix
                if let first = processLines.first {
                    lines.append(indentString(1) + "- " + first.trimmingCharacters(in: .whitespaces))
                    for line in processLines.dropFirst() {
                        // Indent extra 2 to align under the "- " content
                        lines.append(indentString(2) + line.trimmingCharacters(in: .whitespaces))
                    }
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    public func encode(_ elements: [UIElement]) -> String {
        var lines: [String] = []
        for element in elements {
            let elementLines = encodeElement(element, indent: 0)
            if let first = elementLines.first {
                lines.append("- " + first.trimmingCharacters(in: .whitespaces))
                for eLine in elementLines.dropFirst() {
                    lines.append(indentString(1) + eLine.trimmingCharacters(in: .whitespaces))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    public func encode(_ element: UIElement) -> String {
        encodeElement(element, indent: 0).joined(separator: "\n")
    }

    public func encode(_ processes: [ProcessInfo]) -> String {
        var lines: [String] = []
        for process in processes {
            let processLines = encodeProcess(process, indent: 0)
            if let first = processLines.first {
                lines.append("- " + first.trimmingCharacters(in: .whitespaces))
                for pLine in processLines.dropFirst() {
                    lines.append(indentString(1) + pLine.trimmingCharacters(in: .whitespaces))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Encode simple key-value pairs (useful for action results, etc.).
    public func encode(_ pairs: [(key: String, value: String)]) -> String {
        pairs.compactMap { pair in
            line(pair.key, pair.value, indent: 0)
        }.joined(separator: "\n")
    }

    // MARK: - Internal Helpers

    func encodeElement(_ element: UIElement, indent: Int) -> [String] {
        var lines: [String] = []
        let prefix = indentString(indent)

        lines.append(prefix + "role: \(element.role)")

        if let l = line("title", element.title, indent: indent) { lines.append(l) }
        if let l = line("value", element.value, indent: indent) { lines.append(l) }
        if let l = line("identifier", element.identifier, indent: indent) { lines.append(l) }
        if let l = line("label", element.label, indent: indent) { lines.append(l) }
        if let l = line("roleDescription", element.roleDescription, indent: indent) { lines.append(l) }
        lines.append(prefix + "id: \(element.id.uuidString)")

        if let pos = element.position {
            lines.append(prefix + "position: \(formatNumber(pos.x)), \(formatNumber(pos.y))")
        }
        if let sz = element.size {
            lines.append(prefix + "size: \(formatNumber(sz.width)), \(formatNumber(sz.height))")
        }

        lines.append(line("enabled", element.isEnabled, indent: indent))
        lines.append(line("focused", element.isFocused, indent: indent))
        lines.append(prefix + "depth: \(element.depth)")

        if !element.actions.isEmpty {
            lines.append(prefix + "actions:")
            for action in element.actions {
                lines.append(indentString(indent + 1) + "- \(action)")
            }
        }

        if !element.customContent.isEmpty {
            lines.append(prefix + "customContent:")
            for (key, value) in element.customContent.sorted(by: { $0.key < $1.key }) {
                if let l = line(key, value, indent: indent + 1) {
                    lines.append(l)
                }
            }
        }

        if !element.children.isEmpty {
            lines.append(prefix + "children:")
            for child in element.children {
                let childLines = encodeElement(child, indent: indent + 2)
                if let first = childLines.first {
                    lines.append(indentString(indent + 1) + "- " + first.trimmingCharacters(in: .whitespaces))
                    for cLine in childLines.dropFirst() {
                        lines.append(indentString(indent + 2) + cLine.trimmingCharacters(in: .whitespaces))
                    }
                }
            }
        }

        return lines
    }

    func encodeProcess(_ process: ProcessInfo, indent: Int) -> [String] {
        var lines: [String] = []
        let prefix = indentString(indent)

        if let l = line("name", process.name, indent: indent) { lines.append(l) }
        lines.append(prefix + "pid: \(process.pid)")
        if let l = line("bundleIdentifier", process.bundleIdentifier, indent: indent) { lines.append(l) }
        lines.append(line("active", process.isActive, indent: indent))
        lines.append(line("hidden", process.isHidden, indent: indent))

        if !process.windows.isEmpty {
            lines.append(prefix + "windows:")
            for window in process.windows {
                let windowLines = encodeElement(window, indent: indent + 2)
                if let first = windowLines.first {
                    lines.append(indentString(indent + 1) + "- " + first.trimmingCharacters(in: .whitespaces))
                    for wLine in windowLines.dropFirst() {
                        lines.append(indentString(indent + 2) + wLine.trimmingCharacters(in: .whitespaces))
                    }
                }
            }
        }

        return lines
    }

    /// Returns a key-value line, or nil if value is nil (skip nil values).
    func line(_ key: String, _ value: String?, indent: Int) -> String? {
        guard let value else { return nil }
        let prefix = indentString(indent)
        if needsQuoting(value) {
            return prefix + "\(key): '\(value)'"
        }
        return prefix + "\(key): \(value)"
    }

    /// Returns a key-boolean line.
    func line(_ key: String, _ value: Bool, indent: Int) -> String {
        indentString(indent) + "\(key): \(value)"
    }

    // MARK: - Utilities

    private func indentString(_ level: Int) -> String {
        String(repeating: "  ", count: level)
    }

    /// Determines if a string value needs single-quote wrapping.
    private func needsQuoting(_ value: String) -> Bool {
        if value.isEmpty { return true }
        // Quote if contains special chars or could be ambiguous
        let specialChars: Set<Character> = [":", "'", "\"", "\n", "\t", "#", "{", "}", "[", "]", ",", "&", "*", "?", "|", "-", "<", ">", "=", "!", "%", "@", "`"]
        for char in value {
            if specialChars.contains(char) { return true }
        }
        // Quote if it looks like a boolean or number
        let lower = value.lowercased()
        if lower == "true" || lower == "false" || lower == "null" || lower == "nil" {
            return true
        }
        if Double(value) != nil { return true }
        return false
    }

    /// Format a number: strip trailing zeros for cleaner output.
    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && !value.isInfinite && !value.isNaN {
            return String(format: "%.1f", value)
        }
        return String(value)
    }
}
