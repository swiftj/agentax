import Foundation

/// Single source of truth for the agentax version.
public let agentaxVersion = "0.2.1"

/// Constants for AX attribute and action names used throughout the bridge.
public enum AXTypes {
    // MARK: - Attributes
    public static let role = "AXRole"
    public static let title = "AXTitle"
    public static let value = "AXValue"
    public static let identifier = "AXIdentifier"
    public static let label = "AXDescription"
    public static let roleDescription = "AXRoleDescription"
    public static let position = "AXPosition"
    public static let size = "AXSize"
    public static let enabled = "AXEnabled"
    public static let focused = "AXFocused"
    public static let children = "AXChildren"
    public static let windows = "AXWindows"
    public static let mainWindow = "AXMainWindow"
    public static let focusedWindow = "AXFocusedWindow"
    public static let menuBar = "AXMenuBar"
    public static let frontmost = "AXFrontmost"
    public static let hidden = "AXHidden"

    // MARK: - Actions
    public static let pressAction = "AXPress"
    public static let confirmAction = "AXConfirm"
    public static let cancelAction = "AXCancel"
    public static let incrementAction = "AXIncrement"
    public static let decrementAction = "AXDecrement"
    public static let showMenuAction = "AXShowMenu"
    public static let raiseAction = "AXRaise"

    // MARK: - Roles
    public static let windowRole = "AXWindow"
    public static let buttonRole = "AXButton"
    public static let textFieldRole = "AXTextField"
    public static let staticTextRole = "AXStaticText"
    public static let groupRole = "AXGroup"
    public static let scrollAreaRole = "AXScrollArea"
    public static let menuBarRole = "AXMenuBar"
    public static let menuBarItemRole = "AXMenuBarItem"
    public static let menuRole = "AXMenu"
    public static let menuItemRole = "AXMenuItem"
    public static let applicationRole = "AXApplication"

    // MARK: - Limits
    public static let defaultDepthLimit = 50
    public static let defaultTimeout: TimeInterval = 30
    public static let menuBarTimeout: TimeInterval = 2
}

/// Errors from AX operations.
public enum AXError: Error, Sendable, CustomStringConvertible {
    case notTrusted
    case elementNotFound(String)
    case actionNotSupported(String)
    case attributeError(String)
    case timeout(String)
    case depthLimitExceeded
    case invalidSelector(String)
    case noMatchingElements(String)

    public var description: String {
        switch self {
        case .notTrusted:
            "Accessibility permission not granted. Enable in System Settings > Privacy & Security > Accessibility."
        case .elementNotFound(let msg):
            "Element not found: \(msg)"
        case .actionNotSupported(let msg):
            "Action not supported: \(msg)"
        case .attributeError(let msg):
            "Attribute error: \(msg)"
        case .timeout(let msg):
            "Timeout: \(msg)"
        case .depthLimitExceeded:
            "Depth limit exceeded (\(AXTypes.defaultDepthLimit))"
        case .invalidSelector(let msg):
            "Invalid selector: \(msg)"
        case .noMatchingElements(let msg):
            "No matching elements: \(msg)"
        }
    }
}

/// Output format selection.
public enum OutputFormat: String, Sendable, CaseIterable {
    case toon
    case json
}
