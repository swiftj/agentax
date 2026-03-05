import Foundation
import ApplicationServices
import CoreGraphics

/// Result of performing an action on a UI element.
public struct ActionResult: Sendable, Codable {
    public let success: Bool
    public let elementId: UUID
    public let action: String
    public let message: String?

    public init(success: Bool, elementId: UUID, action: String, message: String? = nil) {
        self.success = success
        self.elementId = elementId
        self.action = action
        self.message = message
    }
}

/// Direction for scroll actions.
public enum ScrollDirection: String, Sendable, Codable, CaseIterable {
    case up, down, left, right
}

/// Executes actions on UI elements via their live AXUIElement references.
///
/// Elements are looked up from `ElementStore` by UUID, giving O(1) resolution
/// without re-traversing the AX tree.
@MainActor
public final class ActionExecutor {
    private let elementStore: ElementStore

    public init(elementStore: ElementStore) {
        self.elementStore = elementStore
    }

    // MARK: - Public API

    /// Click an element via the AXPress action.
    public func click(elementId: UUID) throws -> ActionResult {
        try performAction(elementId: elementId, action: AXTypes.pressAction)
    }

    /// Set the value of a text field or other value-holding element.
    public func setValue(elementId: UUID, value: String) throws -> ActionResult {
        let ref = try resolveElement(id: elementId)

        let result = AXUIElementSetAttributeValue(
            ref,
            AXTypes.value as CFString,
            value as CFTypeRef
        )

        guard result == .success else {
            return ActionResult(
                success: false,
                elementId: elementId,
                action: "setValue",
                message: "AXError code \(result.rawValue) setting value"
            )
        }

        return ActionResult(
            success: true,
            elementId: elementId,
            action: "setValue",
            message: "Value set to: \(value)"
        )
    }

    /// Perform any named AX action on an element (e.g., AXPress, AXConfirm, AXShowMenu).
    public func performAction(elementId: UUID, action: String) throws -> ActionResult {
        let ref = try resolveElement(id: elementId)

        // Verify the action is supported by this element
        var actionsRef: CFArray?
        let listResult = AXUIElementCopyActionNames(ref, &actionsRef)
        if listResult == .success, let actions = actionsRef as? [String] {
            guard actions.contains(action) else {
                throw AXError.actionNotSupported(
                    "\(action) not in supported actions: \(actions.joined(separator: ", "))"
                )
            }
        }

        let result = AXUIElementPerformAction(ref, action as CFString)

        guard result == .success else {
            return ActionResult(
                success: false,
                elementId: elementId,
                action: action,
                message: "AXError code \(result.rawValue) performing \(action)"
            )
        }

        return ActionResult(
            success: true,
            elementId: elementId,
            action: action,
            message: nil
        )
    }

    /// Scroll an element in the given direction.
    ///
    /// Uses CGEvent scroll wheel events posted at the element's center position.
    public func scroll(elementId: UUID, direction: ScrollDirection, amount: Int = 3) throws -> ActionResult {
        let ref = try resolveElement(id: elementId)

        // Get element position and size to find center point
        let center = try elementCenter(ref: ref, elementId: elementId)

        // Move mouse to element center first
        if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                   mouseCursorPosition: center, mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.05)
        }

        // Create scroll event
        let (deltaY, deltaX): (Int32, Int32) = switch direction {
        case .up:    (Int32(amount), 0)
        case .down:  (Int32(-amount), 0)
        case .left:  (0, Int32(amount))
        case .right: (0, Int32(-amount))
        }

        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: deltaY,
            wheel2: deltaX,
            wheel3: 0
        ) else {
            return ActionResult(
                success: false,
                elementId: elementId,
                action: "scroll.\(direction.rawValue)",
                message: "Failed to create scroll event"
            )
        }

        scrollEvent.post(tap: .cghidEventTap)

        return ActionResult(
            success: true,
            elementId: elementId,
            action: "scroll.\(direction.rawValue)",
            message: "Scrolled \(direction.rawValue) by \(amount)"
        )
    }

    // MARK: - Private Helpers

    /// Resolve a UUID to a live AXUIElement, throwing if not found.
    private func resolveElement(id: UUID) throws -> AXUIElement {
        guard let ref = elementStore.find(id: id) else {
            throw AXError.elementNotFound(id.uuidString)
        }
        return ref
    }

    /// Get the center point of an AXUIElement from its position and size attributes.
    private func elementCenter(ref: AXUIElement, elementId: UUID) throws -> CGPoint {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let posResult = AXUIElementCopyAttributeValue(ref, AXTypes.position as CFString, &posValue)
        let sizeResult = AXUIElementCopyAttributeValue(ref, AXTypes.size as CFString, &sizeValue)

        guard posResult == .success, sizeResult == .success,
              let posVal = posValue, let sizeVal = sizeValue else {
            throw AXError.attributeError(
                "Cannot read position/size for element \(elementId.uuidString)"
            )
        }

        var point = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else {
            throw AXError.attributeError(
                "Cannot convert position/size values for element \(elementId.uuidString)"
            )
        }

        return CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
    }
}
