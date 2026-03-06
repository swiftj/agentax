Apple Accessibility can work with RealityKit on macOS, but there are some important nuances. The short answer is:
	•	✅ Accessibility APIs are supported in RealityKit itself
	•	✅ They can work in macOS RealityKit apps
	•	⚠️ But macOS support is more limited and requires manual wiring compared with SwiftUI/AppKit UI elements.

Below is the detailed explanation.

⸻

1. RealityKit Has Built-in Accessibility APIs

RealityKit includes accessibility support directly in its entity/component system. You can mark 3D entities as accessibility elements and provide labels and actions.

For example:

entity.isAccessibilityElement = true
entity.accessibilityLabel = "Spaceship"

RealityKit also exposes an AccessibilityComponent to describe actions and semantics for an entity.  ￼

Typical properties include:
	•	isAccessibilityElement
	•	accessibilityLabel
	•	accessibilityValue
	•	accessibilityTraits
	•	AccessibilityComponent actions

These allow assistive technologies (VoiceOver, Switch Control, etc.) to interact with objects in a 3D scene.

⸻

2. This Works on macOS — But Through the macOS Accessibility System

On macOS, accessibility ultimately routes through NSAccessibility.

RealityKit itself does not replace the macOS accessibility tree. Instead:
	•	RealityKit entities can expose accessibility metadata
	•	The hosting view (RealityView / ARView / NSView) bridges it to macOS accessibility APIs

So a typical stack looks like this:

macOS Accessibility
      ↑
NSAccessibility
      ↑
NSView / SwiftUI view
      ↑
RealityView / ARView
      ↑
RealityKit Entities

That means VoiceOver and other assistive technologies can identify entities that you mark as accessible.

⸻

3. Differences vs iOS / visionOS

This is where things get subtle.

iOS / visionOS
	•	Accessibility for spatial content is actively evolving
	•	Apple provides more built-in spatial interaction support
	•	VoiceOver is aware of 3D objects and spatial layout

macOS
	•	Accessibility works, but it’s more generic
	•	The system often sees the hosting view, not every entity
	•	Developers sometimes need to expose entities as accessibility elements manually.

⸻

4. Practical Limitations on macOS Today

In practice, developers often need to:
	1.	Provide labels for important entities
	2.	Add custom accessibility actions
	3.	Possibly mirror key controls in SwiftUI/AppKit UI

Example:

entity.components.set(
    AccessibilityComponent(
        label: "Planet Earth",
        traits: .button
    )
)

This allows VoiceOver users to interact with the object.

⸻

5. Recommended Architecture for macOS RealityKit Accessibility

For production macOS apps, the best pattern is usually:

RealityKit for visuals + SwiftUI for accessibility controls

Example:

SwiftUI Accessibility Controls
        ↓
Accessibility Actions
        ↓
RealityKit Scene

This ensures screen readers have predictable UI elements.

⸻

6. Good News for Your Mac-native RealityKit App

Since you’re building a native macOS SwiftUI + RealityKit app, the typical stack works well:

SwiftUI Window
   ↓
RealityView
   ↓
RealityKit Entities

You can:
	•	expose entity metadata
	•	attach SwiftUI accessibility elements
	•	map gestures/actions to entities

This gives VoiceOver a usable interaction model.

⸻

✅ Summary

Question	Answer
Does RealityKit support accessibility?	Yes
Does it work on macOS?	Yes
Is it automatic?	No — developers must mark entities
Does it integrate with macOS accessibility?	Yes via NSAccessibility
Is support richer on visionOS?	Yes
