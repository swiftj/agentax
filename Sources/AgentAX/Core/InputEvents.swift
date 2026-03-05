import Foundation
import CoreGraphics

/// Modifier keys for key combinations.
public enum KeyModifier: String, Sendable, Codable, CaseIterable {
    case command, shift, control, option

    public var cgFlag: CGEventFlags {
        switch self {
        case .command:  .maskCommand
        case .shift:    .maskShift
        case .control:  .maskControl
        case .option:   .maskAlternate
        }
    }
}

/// Low-level CGEvent-based input simulation for mouse and keyboard.
///
/// All mouse coordinates are absolute screen positions.
/// Requires Accessibility permission granted to the parent process.
@MainActor
public final class InputEventGenerator {

    /// Delay between key-down and key-up events (seconds).
    private let keyDelay: TimeInterval = 0.01
    /// Delay between mouse-down and mouse-up events (seconds).
    private let clickDelay: TimeInterval = 0.01

    public init() {}

    // MARK: - Mouse Events

    /// Click at absolute screen coordinates.
    public func clickAtPosition(x: Double, y: Double) throws {
        let point = CGPoint(x: x, y: y)
        try postMouseEvent(type: .leftMouseDown, point: point, button: .left)
        Thread.sleep(forTimeInterval: clickDelay)
        try postMouseEvent(type: .leftMouseUp, point: point, button: .left)
    }

    /// Right-click at absolute screen coordinates.
    public func rightClickAtPosition(x: Double, y: Double) throws {
        let point = CGPoint(x: x, y: y)
        try postMouseEvent(type: .rightMouseDown, point: point, button: .right)
        Thread.sleep(forTimeInterval: clickDelay)
        try postMouseEvent(type: .rightMouseUp, point: point, button: .right)
    }

    /// Double-click at absolute screen coordinates.
    public func doubleClickAtPosition(x: Double, y: Double) throws {
        let point = CGPoint(x: x, y: y)

        guard let down1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                  mouseCursorPosition: point, mouseButton: .left),
              let up1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                                mouseCursorPosition: point, mouseButton: .left),
              let down2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                  mouseCursorPosition: point, mouseButton: .left),
              let up2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                                mouseCursorPosition: point, mouseButton: .left) else {
            throw InputEventError.eventCreationFailed("double-click")
        }

        down1.setIntegerValueField(.mouseEventClickState, value: 1)
        up1.setIntegerValueField(.mouseEventClickState, value: 1)
        down2.setIntegerValueField(.mouseEventClickState, value: 2)
        up2.setIntegerValueField(.mouseEventClickState, value: 2)

        down1.post(tap: .cghidEventTap)
        up1.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: clickDelay)
        down2.post(tap: .cghidEventTap)
        up2.post(tap: .cghidEventTap)
    }

    /// Drag from one position to another over a duration.
    public func drag(fromX: Double, fromY: Double, toX: Double, toY: Double,
                     duration: TimeInterval = 0.5) throws {
        let from = CGPoint(x: fromX, y: fromY)
        let to = CGPoint(x: toX, y: toY)
        let steps = max(Int(duration / 0.016), 5) // ~60fps, minimum 5 steps

        // Mouse down at start
        try postMouseEvent(type: .leftMouseDown, point: from, button: .left)

        // Interpolate drag positions
        let stepDelay = duration / Double(steps)
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let current = CGPoint(
                x: from.x + (to.x - from.x) * t,
                y: from.y + (to.y - from.y) * t
            )
            try postMouseEvent(type: .leftMouseDragged, point: current, button: .left)
            Thread.sleep(forTimeInterval: stepDelay)
        }

        // Mouse up at end
        try postMouseEvent(type: .leftMouseUp, point: to, button: .left)
    }

    // MARK: - Keyboard Events

    /// Type a text string by posting unicode key events for each character.
    public func typeText(_ text: String) throws {
        for scalar in text.unicodeScalars {
            guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
                throw InputEventError.eventCreationFailed("keyboard event for '\(scalar)'")
            }

            var utf16Char = UInt16(truncatingIfNeeded: scalar.value)
            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &utf16Char)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &utf16Char)

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: keyDelay)
        }
    }

    /// Press a key combination (e.g., Cmd+C, Shift+Cmd+Z).
    public func keyCombination(key: String, modifiers: [KeyModifier] = []) throws {
        guard let keyCode = Self.keyCodeMap[key.lowercased()] else {
            throw InputEventError.unknownKey(key)
        }

        let flags = modifiers.reduce(CGEventFlags()) { flags, mod in
            CGEventFlags(rawValue: flags.rawValue | mod.cgFlag.rawValue)
        }

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw InputEventError.eventCreationFailed("key combination \(key)")
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: keyDelay)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Press a single key by virtual key code.
    public func keyPress(_ keyCode: UInt16) throws {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw InputEventError.eventCreationFailed("keyPress \(keyCode)")
        }

        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: keyDelay)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Private Helpers

    private func postMouseEvent(type: CGEventType, point: CGPoint, button: CGMouseButton) throws {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type,
                                  mouseCursorPosition: point, mouseButton: button) else {
            throw InputEventError.eventCreationFailed("\(type)")
        }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Key Code Map

    /// Virtual key codes for common keys on a US keyboard layout.
    nonisolated(unsafe) static let keyCodeMap: [String: UInt16] = [
        // Letters
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
        "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
        "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
        "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
        "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
        "z": 0x06,

        // Numbers
        "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
        "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,

        // Special keys
        "return": 0x24, "enter": 0x24,
        "tab": 0x30,
        "space": 0x31,
        "delete": 0x33, "backspace": 0x33,
        "forwarddelete": 0x75,
        "escape": 0x35, "esc": 0x35,

        // Arrow keys
        "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
        "leftarrow": 0x7B, "rightarrow": 0x7C, "downarrow": 0x7D, "uparrow": 0x7E,

        // Function keys
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
        "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
        "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F,

        // Modifiers (for standalone press)
        "command": 0x37, "shift": 0x38, "option": 0x3A, "control": 0x3B,
        "rightcommand": 0x36, "rightshift": 0x3C, "rightoption": 0x3D, "rightcontrol": 0x3E,
        "capslock": 0x39,

        // Punctuation / symbols
        "minus": 0x1B, "-": 0x1B,
        "equal": 0x18, "=": 0x18,
        "leftbracket": 0x21, "[": 0x21,
        "rightbracket": 0x1E, "]": 0x1E,
        "backslash": 0x2A, "\\": 0x2A,
        "semicolon": 0x29, ";": 0x29,
        "quote": 0x27, "'": 0x27,
        "comma": 0x2B, ",": 0x2B,
        "period": 0x2F, ".": 0x2F,
        "slash": 0x2C, "/": 0x2C,
        "grave": 0x32, "`": 0x32,

        // Navigation
        "home": 0x73, "end": 0x77,
        "pageup": 0x74, "pagedown": 0x79,
    ]
}

/// Errors from input event generation.
public enum InputEventError: Error, Sendable, CustomStringConvertible {
    case eventCreationFailed(String)
    case unknownKey(String)

    public var description: String {
        switch self {
        case .eventCreationFailed(let detail):
            "Failed to create CGEvent: \(detail)"
        case .unknownKey(let key):
            "Unknown key name: \(key). Use a-z, 0-9, return, tab, space, delete, escape, arrows, f1-f12, or punctuation names."
        }
    }
}
