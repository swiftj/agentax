import Foundation
import ApplicationServices

/// A captured UI element from the AX tree with a stable UUID for O(1) lookup.
public struct UIElement: Sendable, Identifiable, Codable {
    public let id: UUID
    public var role: String
    public var title: String?
    public var value: String?
    public var identifier: String?
    public var label: String?
    public var roleDescription: String?
    public var position: CGPoint?
    public var size: CGSize?
    public var isEnabled: Bool
    public var isFocused: Bool
    public var actions: [String]
    public var customContent: [String: String]
    public var children: [UIElement]
    public var depth: Int

    public init(
        id: UUID = UUID(),
        role: String,
        title: String? = nil,
        value: String? = nil,
        identifier: String? = nil,
        label: String? = nil,
        roleDescription: String? = nil,
        position: CGPoint? = nil,
        size: CGSize? = nil,
        isEnabled: Bool = true,
        isFocused: Bool = false,
        actions: [String] = [],
        customContent: [String: String] = [:],
        children: [UIElement] = [],
        depth: Int = 0
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.value = value
        self.identifier = identifier
        self.label = label
        self.roleDescription = roleDescription
        self.position = position
        self.size = size
        self.isEnabled = isEnabled
        self.isFocused = isFocused
        self.actions = actions
        self.customContent = customContent
        self.children = children
        self.depth = depth
    }

    enum CodingKeys: String, CodingKey {
        case id, role, title, value, identifier, label, roleDescription
        case position, size, isEnabled, isFocused, actions, customContent
        case children, depth
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(String.self, forKey: .role)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        roleDescription = try container.decodeIfPresent(String.self, forKey: .roleDescription)

        if let posArray = try container.decodeIfPresent([CGFloat].self, forKey: .position), posArray.count == 2 {
            position = CGPoint(x: posArray[0], y: posArray[1])
        } else {
            position = nil
        }
        if let sizeArray = try container.decodeIfPresent([CGFloat].self, forKey: .size), sizeArray.count == 2 {
            size = CGSize(width: sizeArray[0], height: sizeArray[1])
        } else {
            size = nil
        }

        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        isFocused = try container.decodeIfPresent(Bool.self, forKey: .isFocused) ?? false
        actions = try container.decodeIfPresent([String].self, forKey: .actions) ?? []
        customContent = try container.decodeIfPresent([String: String].self, forKey: .customContent) ?? [:]
        children = try container.decodeIfPresent([UIElement].self, forKey: .children) ?? []
        depth = try container.decodeIfPresent(Int.self, forKey: .depth) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(roleDescription, forKey: .roleDescription)
        if let pos = position {
            try container.encode([pos.x, pos.y], forKey: .position)
        }
        if let sz = size {
            try container.encode([sz.width, sz.height], forKey: .size)
        }
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isFocused, forKey: .isFocused)
        if !actions.isEmpty { try container.encode(actions, forKey: .actions) }
        if !customContent.isEmpty { try container.encode(customContent, forKey: .customContent) }
        if !children.isEmpty { try container.encode(children, forKey: .children) }
        try container.encode(depth, forKey: .depth)
    }
}

extension UIElement: Equatable {
    public static func == (lhs: UIElement, rhs: UIElement) -> Bool {
        lhs.id == rhs.id
    }
}

extension UIElement: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
