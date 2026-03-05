# **Architecting Autonomous AI Agent Testing for macOS: Transitioning from Vision-Based to Semantic Accessibility Frameworks in SwiftUI and RealityKit**

## **Introduction to Autonomous Agentic Testing in Hybrid macOS Environments**

The integration of Large Language Models (LLMs) and autonomous agents into the software development lifecycle represents a profound paradigm shift in quality assurance and automated testing methodologies. Historically, testing native macOS applications required rigidly defined, explicitly scripted frameworks such as XCUITest, or complex third-party middleware solutions like Appium. These traditional frameworks, while highly deterministic, demand significant engineering overhead to establish, maintain, and update in response to shifting user interface designs. However, the emergence of agentic coding tools—particularly those utilizing the Model Context Protocol (MCP) such as Claude Code—has enabled a new frontier characterized by autonomous, self-directed user interface testing.

When engineering automated testing solutions for modern macOS applications that seamlessly blend traditional two-dimensional interfaces developed in SwiftUI with immersive three-dimensional spatial environments rendered via RealityKit, the architectural complexity of automation scales exponentially. Initial attempts to bridge this automation gap have heavily relied on vision-based agents. These systems operate by capturing the screen, parsing the resulting pixels using computer vision algorithms or multimodal large language models, and simulating human input based on visual inferences. While these vision-centric methodologies offer a virtually zero-instrumentation setup, they introduce severe systemic bottlenecks regarding execution latency, computational token consumption, and probabilistic determinism.

This comprehensive research report provides an exhaustive, granular analysis of the optimal architectural solutions for allowing AI agents to autonomously test hybrid SwiftUI and RealityKit macOS applications. The analysis deconstructs the inherent limitations of current vision-centric utilities like Peekaboo, explores the necessary transition toward programmatic semantic Accessibility (AX) tree extraction, investigates advanced serialization formats designed specifically for LLM token optimization, and defines the precise code-level architectural patterns required to expose complex three-dimensional RealityKit entities to text-based artificial intelligence models.

## **The Architectural Bottleneck of Vision-Based Automation**

The current industry standard for deploying zero-setup AI user interface automation heavily leans on advanced vision capabilities. Tools operating in this space are designed to replicate human visual processing to interact with the operating system.

### **Operational Mechanics of Vision MCPs and Peekaboo**

Peekaboo serves as a prime example of a comprehensive macOS user interface automation Command Line Interface (CLI) and Model Context Protocol server. The framework is engineered to capture and inspect screens, target specific UI elements, drive peripheral input, and manage the full lifecycle of applications, windows, menus, and system dialogs.1 Operating on macOS 15 and requiring Xcode 16 and Swift 6.2 for development, Peekaboo provides advanced snapshot caching and machine-readable JSON output for reliable scripting.1 Its core features include live capture and video frame extraction, precise element targeting, and comprehensive interaction primitives such as click, drag, hotkey, move, paste, press, scroll, swipe, and type.1

By integrating with the macOS Accessibility and Screen Recording Application Programming Interfaces (APIs), Peekaboo allows an agent like Claude to control the operating system directly through a robust command-line interface.3 Developers can utilize commands like peekaboo image \--app "MyApp" \--analyze "Do you see three buttons here?" to prompt an external agent to evaluate the visual state of an application.4 While these tools provide extensive application lifecycle management and human-like input simulation with adjustable typing speeds, they fundamentally rely on processing high-resolution imagery through multimodal LLMs.3

### **The Context Exhaustion and Token Hunger Dilemma**

The primary constraint of vision-based testing within an agentic framework is its immense and often unsustainable token hunger. When an artificial intelligence agent evaluates a user interface visually, the captured image is parsed into thousands of visual tokens. Even with modern optimization techniques—such as UI-Guided Visual Token Selection, an approach that treats screenshots as connected graphs to identify redundant visual areas while preserving critical elements—the computational load remains exceptionally heavy. Research indicates that while such token selection optimizations can reduce visual tokens by 33 percent and accelerate training by a factor of 1.4, the baseline token consumption of images still dwarfs that of text.5

For an automated testing pipeline utilizing a framework like Peekaboo, continuously feeding sequential screenshots to an agent like Claude Code rapidly saturates the model's context window.1 The context window represents the maximum number of tokens an LLM can process in a single inference operation, including the original user prompt and all appended historical state data.6 Large language models charge per token, meaning that processing sequential frames of a macOS desktop to verify a multi-step test flow escalates operational and financial costs dramatically.6 Furthermore, Anthropic's native AiComputerUse beta interface—which provides underlying computer control capabilities—is widely reported to consume a highly significant number of tokens, making local or high-frequency continuous integration runs financially prohibitive.7 The context saturation caused by visual data fundamentally limits the agent's ability to retain long-term memory of the test suite's objectives, leading to amnesia regarding earlier test steps.

### **Latency, Stochasticity, and Bias in Vision Models**

Beyond the prohibitive cost and context window exhaustion, vision-based agents suffer from severe execution latency. The mechanical round-trip time required to execute a live screen capture, extract specific frames, encode the image into a base64 string, transmit the payload to the LLM API, await the remote visual analysis, and receive the localized coordinate instructions for a simple click or drag event introduces a massive execution delay.1 When compared to unit tests that execute in fractions of a second, visual UI tests that require tens of seconds per interaction step drastically decelerate the development pipeline.

Additionally, visual models are inherently stochastic and susceptible to environmental variations. They are subject to biases based on layout densities, localized color schemes, and rendering discrepancies. Analytical research and multi-brand testing results from organizations such as UXVerify Labs demonstrate that bias in training data leads to uneven performance in vision models.8 Datasets containing fewer than 10,000 images are statistically likely to exhibit significant bias in AI training, resulting in models that fail to generalize across diverse user interface layouts.8 Consequently, a minor graphical artifact, a subtle change in the macOS system theme (such as transitioning from Light to Dark Mode), or a varying display resolution can cause a vision agent to completely misinterpret the screen state. The fundamental architecture of automated software testing demands absolute determinism; relying on the probabilistic interpretation of pixels introduces a layer of fragility and test flakiness that is fundamentally incompatible with rigorous software validation.

## **The Semantic Paradigm: Accessibility (AX) Tree Extraction**

To circumvent the profound limitations of vision-based agents, the optimal architectural solution necessitates a paradigm shift from visual interpretation to semantic extraction. Every native application developed for macOS, including those built utilizing the declarative SwiftUI framework, generates an underlying Accessibility (AX) tree. This tree is a structured, hierarchical mathematical representation of the user interface maintained continuously by the operating system.9 Originally designed to facilitate assistive technologies such as VoiceOver for visually impaired users, the AX tree provides a deeply detailed, text-based map of every interactive element on the screen.9

By extracting this AX tree and feeding it directly into the context window of a Large Language Model, the AI agent receives a deterministic, exact representation of the UI state. This semantic approach bypasses the need for screenshots entirely, reducing token count by orders of magnitude while accelerating processing speed. The agent no longer has to guess if a collection of pixels represents a button; the operating system explicitly guarantees that the node is a button, provides its exact bounding box coordinates, and declares its current interaction state.

### **Programmatic Access to the macOS Accessibility Layer**

Several emerging technologies, robust daemons, and Model Context Protocol servers have been rapidly developed to expose the macOS AX tree directly to artificial intelligence agents. These specialized tools effectively transform the operating system's visual UI layer into a highly structured, queryable programmatic dataset.

| Extraction Tool | Architecture Type | Data Output Format | Core Mechanism | Native Platform Focus |
| :---- | :---- | :---- | :---- | :---- |
| **DirectShell** | Background Daemon | SQLite Database / SQL | Continuously dumps UIA tree into a relational database for SQL INSERT control. | Windows / Universal 10 |
| **OculOS** | Daemon / MCP Server | REST API / JSON | Reads OS accessibility tree natively; provides WebSockets and direct agent endpoints. | macOS / Cross-platform 11 |
| **Macapptree** | Python CLI Library | Hierarchical JSON | Extracts specific app bundles or full-screen bounding box coordinates recursively. | macOS 12 |
| **Xctree** | Swift CLI Tool | JSON / Text Tree | Extracts accessibility properties specifically from iOS and macOS simulator environments. | macOS Simulators 13 |
| **macos-ui-automation-mcp** | Python MCP Server | JSONPath / JSON | Acts as "Playwright for Swift," allowing direct Claude Code queries to the AX API. | macOS 14 |

#### **Daemon-Based Extraction: OculOS and DirectShell**

For continuous, high-speed automated testing, background daemons that maintain a real-time map of the accessibility tree offer unprecedented performance. OculOS is a lightweight daemon written in the Rust programming language that operates with zero external dependencies. It reads the operating system's accessibility tree and exposes every button, text field, checkbox, and menu item as a structured JSON endpoint.11 Functioning simultaneously as a REST API for traditional scripts and as a dedicated MCP server for AI agents like Claude Code, OculOS operates entirely without screenshots, pixel coordinates, browser extensions, or code injection.11 By simply granting the terminal application macOS Accessibility permissions, OculOS empowers Claude Code to autonomously locate applications, focus windows, and execute complex workflows deterministically.11

Approaching the paradigm from a database perspective, DirectShell conceptualizes the accessibility layer as universal software infrastructure. Recognizing that the accessibility tree has existed since 1997 and SQL databases since the 1970s, DirectShell combines them into a universal interface primitive.10 It continuously dumps the accessibility tree into a queryable SQLite database at real-time refresh rates, providing a universal action queue where any external process or AI agent can control the application via standard SQL INSERT commands.10 While initial implementations heavily targeted Windows UI Automation, the architectural concept of querying a SQLite database of UI elements is significantly faster and more structured than visually scanning a screenshot or parsing deep JSON files.

#### **Command-Line and Script-Based Extraction: Macapptree and Xctree**

For development teams requiring programmatic extraction without maintaining persistent background daemons, Python and Swift-based CLI tools present highly effective solutions. Maintained by the research division at MacPaw, the macapptree Python package is specifically designed to extract the accessibility tree of macOS application screens in JSON format.12 It supports multi-app capturing, upper menu inclusion, and dock inclusion via CLI arguments such as \--all-apps and \--include-menubar.12

The structural schema of the JSON output generated by macapptree is meticulously detailed. Each node within the tree contains critical semantic fields, including a unique string id, the element's name, its functional role (e.g., "AXWindow", "AXScrollArea"), a human-readable role\_description, and its current active value.12 Crucially for autonomous agents, it provides precise spatial awareness through the absolute\_position coordinates, relative position coordinates, dimensional size, and an integer list representing the exact bbox (bounding box) on the screen.12 Armed with this data, an agent like Claude Code can parse the JSON, locate the exact coordinates of a target element, and execute a programmatic click without ever requiring visual validation.

Alternatively, xctree provides a robust Swift-based command-line tool tailored for extracting the accessibility tree from applications running within the iOS and macOS Simulator environments.13 Operating as a programmatic alternative to Xcode's native Accessibility Inspector, xctree extracts structured views of UI roles, labels, values, traits, hints, and identifiers.13 Outputting in either a color-coded text tree or structured JSON format, it allows coding agents to perfectly understand an application's UI structure, making it highly valuable for verifying Web Content Accessibility Guidelines (WCAG) compliance seamlessly during the automated testing phase.13

#### **Direct Agent Integration: macOS UI Automation MCP**

Perhaps the most direct and highly specialized replacement for vision-based tools like Peekaboo is the macos-ui-automation-mcp server.14 Described by its maintainers as the "Playwright for Swift development," this MCP server grants Claude the direct ability to see and interact with any macOS application utilizing the native accessibility API rather than fragile AppleScript commands or token-heavy vision pipelines.14

By bypassing visual analysis entirely, it enables high-speed, programmatic UI testing. The AI agent can query the MCP to find all running applications, isolate specific buttons by their accessibility identifier or semantic label, and verify application functionality autonomously.15 A similar experimental implementation, AutoMac MCP, provides complete control of the local OS UI using Anthropic's AI-powered coding assistant for rapid prototyping, relying strictly on macOS accessibility and screen recording permissions to execute actions directly via localized Python scripts.17 Unlike rigid testing scripts, the agent utilizes JSONPath queries to dynamically filter the accessibility tree, allowing for flexible, resilient element targeting even if the underlying layout undergoes minor structural modifications.10

## **Engineering 3D Semantic Visibility: RealityKit and the AccessibilityComponent**

The architectural transition to semantic AX tree testing is relatively straightforward for two-dimensional applications built utilizing SwiftUI, as Apple's native framework components automatically populate the accessibility tree by default.9 However, when a user's application relies heavily on RealityKit to render spatial computing experiences, a severe architectural hurdle emerges. RealityKit is designed around an Entity Component System (ECS) architecture, and its entities do not provide any form of accessibility information to the operating system by default.9

If a macOS or visionOS game renders a three-dimensional ModelEntity—such as a 3D game character, a floating volumetric menu, a spatial geometric primitive like a sphere or a box generated via MeshResource.generateBox, or complex models loaded asynchronously via ModelEntity(named:)—that object is entirely invisible to the accessibility tree.9 Consequently, an AI agent reading the AX tree via an MCP server will be completely unaware of the 3D game state, rendering automated testing of the RealityKit layer impossible. To rectify this fundamental limitation, the developer must explicitly expose RealityKit 3D entities to the macOS accessibility layer through rigorous codebase instrumentation.

### **The Entity Component System and the RealityKit Black Box**

RealityKit abstracts traditional scene-graph architectures by utilizing an Entity Component System. Within this paradigm, an Entity is merely an empty container.18 Functionality, rendering, and physics are dictated entirely by the components attached to the entity. For instance, creating a visible 3D box requires instantiating an Entity, generating a MeshResource, creating a SimpleMaterial, wrapping them in a ModelComponent, and appending that component to the entity.19 Similarly, user interactions and animations are managed by specialized components applied to the base entity.18 Because RealityKit abstracts a significant amount of underlying architecture away from the developer, the framework acts as a "black box" where internal properties are not easily exposed or documented for external querying.18

### **Implementing the AccessibilityComponent**

To bridge the critical gap between immersive spatial computing and semantic accessibility, Apple introduced the AccessibilityComponent.21 By explicitly applying this component to a RealityKit Entity, the 3D object is successfully registered as a valid node within the macOS and visionOS AX tree, complete with readable semantic metadata that an artificial intelligence agent can interpret.9

To expose a 3D game element to the AI testing agent, the developer must instantiate an AccessibilityComponent and carefully configure its core properties.21 The fundamental properties required for adequate semantic exposure include:

* isAccessibilityElement: A boolean value indicating whether the receiver is an accessibility entity. This must be explicitly set to true to register the entity in the external AX tree.22  
* label: A succinct LocalizedStringResource that identifies the entity (e.g., "Player Character", "Start Button", or "Glass Cube").9 This serves as the primary identifier for the LLM agent.  
* value: A localized string key representing the current state or value of the entity (e.g., "Health: 80%", "Grumpy", or "Selected").21  
* traits: The combination of UIAccessibilityTraits that characterize the entity's functional behavior, such as .button, .playsSound, or .image.21

When these properties are established and the component is set on the target entity (e.g., glassCube.components.set(AccessibilityComponent())), extraction tools like macapptree or the macos-ui-automation-mcp will suddenly be able to "see" the 3D entity programmatically.9 The agent can then use the provided bounding boxes to simulate interactions within the 2D projection of the 3D space.

### **Injecting Proprietary Game State via CustomContent and SystemActions**

For a complex macOS game, basic semantic labels and string values are frequently insufficient for comprehensive functional testing. An autonomous AI agent validating a game requires granular, structured data regarding the 3D environment, such as exact coordinate locations, absolute physical status, collision group intersections, and complex relational states.

To facilitate this deep introspection, RealityKit provides advanced properties within the AccessibilityComponent, most notably customContent, systemActions, and customRotors.22 The customContent property accepts an array of AccessibilityComponent.CustomContent objects designed to deliver highly specific, measured portions of accessibility information from complex data sets.22 While originally intended to leverage assistive technologies to present data to human users in measured portions, from an automated testing perspective, customContent acts as a secure, hidden data channel operating directly between the game engine and the LLM.23

Developers can inject exact 3D world coordinates (x, y, z floats), collision statuses, or proprietary internal game state variables directly into the customContent array. When the MCP server dumps the AX tree into JSON, this rich, proprietary metadata is carried along seamlessly. The AI agent executing via Claude Code can read the semantic tree, identify a 3D RealityKit entity by its label, and read the customContent to mathematically verify that the entity transitioned to the correct coordinate in the 3D space after a simulated action was executed. This architectural pattern entirely eliminates the need for the AI agent to visually estimate three-dimensional spatial positioning using inherently flawed, two-dimensional screenshots.

Furthermore, defining systemActions allows the AI agent to understand which native accessibility actions are supported by the entity, while customRotors enables the agent to navigate complex data arrays associated with the object.22

### **The Convergence of Automated Testing and Human Accessibility**

A profound second-order implication of this architectural requirement is that by rigorously optimizing the RealityKit application for autonomous AI testing, the developer is simultaneously rendering the game fully compliant with global accessibility standards for human users.13

The VoiceOver system operating in macOS and visionOS spatial computing relies on the exact same AccessibilityComponent infrastructure required by the AI agent.9 VoiceOver utilizes distinct physical gestures—such as right index finger pinches to move focus to the next item, and left index finger pinches to activate a targeted item—to navigate the spatial environment.9 By extensively labeling 3D entities, defining their functional traits, and exposing their state variables to ensure the artificial intelligence can test the application, the game inherently becomes fully playable and navigable by blind or low-vision users.9 Thus, the substantial engineering investment required to architect an autonomous AI testing pipeline directly funds and fulfills the application's ethical and legal inclusivity requirements.

## **Token Optimization Strategies for Large Language Models**

While programmatic extraction of the AX tree into standard JSON is vastly superior to processing multi-megapixel screenshots, raw JSON payloads still present a critical token optimization challenge for modern Large Language Models.

### **The Lexical Bloat of JSON in Accessibility Trees**

In complex, highly nested macOS applications, the resulting accessibility tree can be staggeringly deep. The process of walking the view hierarchy often surfaces significant complexities; for instance, SwiftUI does not create standard UIKit elements like a UIButton when a developer declares Button("Confirm"), but rather generates custom elements that can reference each other in unexpected ways, necessitating strict 50-level depth limits to prevent infinite recursion.25

Consequently, raw dumps of the full UI hierarchy into standard JSON can easily exceed payloads of 15,000 tokens.10 The fundamental issue lies in how LLM tokenizers parse text. Every curly brace {, }, square bracket \[, \], and quotation mark " utilized in a JSON payload to express scope and separation is treated as an individual token by the model.26 Furthermore, the continuous repetition of standard key names—such as "id", "type", "frame", or "role"—across hundreds of sequential UI nodes multiplies the token cost exponentially without adding any new semantic meaning.27

### **Token-Oriented Object Notation (TOON) Mechanics**

To maximize the speed, cost-efficiency, and contextual memory of the AI agent, the extracted JSON payload must be compressed into a serialization format explicitly designed for the lexical mechanics of Large Language Models. This architectural requirement is fulfilled by Token-Oriented Object Notation (TOON).

TOON is a modern, lightweight, highly optimized data format designed specifically to make structured data compact, readable, and remarkably token-efficient for LLMs.27 It essentially functions as a reimagining of JSON, stripping away syntactic noise and utilizing indentation and tabular patterns to represent hierarchy.27 By moving structural meaning entirely into whitespace, TOON achieves massive token reductions through several core mechanisms:

1. **Indentation-Based Hierarchy**: Rather than depending on punctuation to express scope, TOON relies on whitespace. Two spaces represent exactly one nesting level, and each new key begins a new line when introducing a child object. Context defines interpretation, entirely eliminating braces.26  
2. **Tabular Arrays**: Rather than repeating structural keys for every individual object within an array, TOON declares the array structure strictly upfront. For example, instead of wrapping every user object in repeating braces and keys, TOON formats the data as users{id,name,role}: followed exclusively by comma-separated values on subsequent lines.27  
3. **Key Folding**: TOON collapses single-key object chains into dotted paths, further flattening deep nested structures and reducing the sheer volume of textual bloat.28

| Feature Comparison | Standard JSON | Token-Oriented Object Notation (TOON) |
| :---- | :---- | :---- |
| **Hierarchy Demarcation** | Braces {} and Brackets \`\` | Indentation (Whitespace) 26 |
| **Array Representation** | Repeated keys for every object | Upfront declaration, Tabular format 27 |
| **Token Efficiency** | Poor (High punctuation penalty) | Excellent (30% \- 60% reduction) 27 |
| **Key Chains** | Deeply nested objects | Folded dotted paths 28 |
| **String Escaping** | Standard \\", \\n | Canonical formatting, \\", \\n 28 |

For macOS UI testing, the standard JSON output retrieved from tools like macapptree or OculOS should be programmatically intercepted and serialized into TOON format before being passed into Claude Code's context window. A native Swift implementation, toon-swift, conforms strictly to TOON specification version 3.0, supporting canonical number formatting, key folding, array length validation, and configurable delimiter types.28

Benchmarks executing direct comparisons utilizing OpenAI's tiktoken tokenizer demonstrate that converting standard JSON to TOON yields a consistent 30% to 60% reduction in total token count.27 This substantial token reduction directly translates to increased operational speed and diminished financial costs. An AI agent processing 4,000 tokens of TOON will generate a cohesive testing strategy and execute subsequent simulated actions significantly faster than an agent tasked with parsing 12,000 tokens of raw, uncompressed JSON, accelerating the automated testing pipeline without sacrificing an ounce of contextual data.27

While alternative experimental formats like TRON (Token Reduced Object Notation) exist—which attempt to introduce Object-Oriented Programming (OOP) features like class instantiation into serialization to further reduce repeated object structures—TOON remains the more widely adopted and structurally stable specification for straightforward LLM integration.29

## **Native Testing Frameworks in an Agentic Context**

While extracting the AX tree via external MCP servers provides an excellent, low-overhead black-box mechanism for an AI agent to interact with the user interface, certain highly complex SwiftUI state validations may require the agent to inspect the internal, native application state directly. To achieve this, the AI agent can be empowered to dynamically execute or analyze the output of Apple's native testing frameworks.

### **XCUITest and Programmatic Snapshot Extraction**

XCUITest is Apple's established, native UI testing framework built directly into Xcode. It operates entirely out-of-process, utilizing the exact same underlying Accessibility API that VoiceOver uses to drive interactions.30 While XCUITest is famously slow to execute—with benchmarks showing simple UI test flows taking upward of 27 seconds compared to unit tests that execute in 0.0023 seconds—and occasionally prone to flakiness due to asynchronous animation states, its underlying native data structures can be exceptionally valuable to an autonomous agent.32

Rather than attempting to force the AI agent to write manual, brittle XCUITest scripts in Swift, the agent can instead utilize XCUITest's native introspection capabilities to passively gather highly detailed application state. Specifically, the debugDescription property of the XCUIApplication object provides an exhaustive, text-based snapshot of the entire active view hierarchy.34 More importantly for data serialization, invoking element.snapshot().dictionaryRepresentation provides a deeply parsed, JSON-compatible dictionary representation of the UI element and all of its iterative children.35

An advanced architectural workflow allows the AI agent to trigger a minimal, headless XCUITest runner in the background.30 This runner's sole purpose is to execute dictionaryRepresentation on the main application window, serialize this deeply structured dictionary into the highly efficient TOON format using toon-swift, and write the output directly to a local file.28 Claude Code can then simply read this compressed file to achieve a perfect, natively validated understanding of the application's hierarchical state.28 This approach successfully bridges the gap between Apple's secure, highly sandboxed UI testing environment and the external, fast-moving AI agent.

### **The Limitations of Appium Mac2Driver**

Historically, Appium has served as the industry standard framework for cross-platform automation, supporting multiple leading programming languages such as Java, Python, and Ruby.32 The Appium Mac2Driver operates strictly within the scope of the W3C WebDriver protocol, utilizing Apple's underlying XCTest framework to execute commands.38

However, within the context of an autonomous AI agent like Claude Code executing locally via the Model Context Protocol, relying on Appium is generally considered an architectural anti-pattern. Appium introduces significant configuration complexity and operational overhead.39 The Mac2Driver demands stringent prerequisites, including specific xcode-select developer directory targeting, explicit Accessibility access for the hidden Xcode Helper app, and highly specific commands like automationmodetool enable-automationmode-without-authentication to bypass testmanagerd UIAutomation authentication prompts that frequently block execution in CI/CD environments.38

Furthermore, Appium adds a heavy Java or Node.js middleware layer designed inherently for traditional, step-by-step scripted CI/CD execution.32 The LLM agent does not require a bulky W3C WebDriver server to translate HTTP commands; it requires immediate, direct access to the operating system's accessibility APIs. Lightweight tools like the macos-ui-automation-mcp or the OculOS daemon provide this direct access with dramatically faster execution speeds and vastly reduced configuration friction.11

### **ViewInspector for Synchronous SwiftUI Validation**

For applications relying heavily on the declarative SwiftUI framework, ViewInspector stands as a highly popular, paradigm-shifting third-party library.40 It dramatically improves the testability of SwiftUI views by allowing developers to deeply inspect the view hierarchy, extract specific view properties, and synchronously simulate user interactions.41 Operating entirely independently of XCUITest, ViewInspector utilizes the official Swift reflection API to mathematically dissect view structures at runtime, making it exceptionally fast.43

An AI agent could theoretically be instructed to dynamically generate and execute ViewInspector tests to validate the 2D UI components of the application. ViewInspector provides immense power, allowing the agent to extract the underlying SwiftUI view to access its attached view model, trigger deep system-control callbacks (e.g., try sut.inspect().find(button: "Close").tap()), and explicitly verify complex state changes within @Binding, @State, @Environment, and @ObservedObject wrappers.41

However, the critical limitation of ViewInspector within this specific hybrid context is its lack of support for RealityKit and complex spatial animations. A multitude of animation-related modifiers—including matchedGeometryEffect, contentTransition, phaseAnimator, and keyframeAnimator—are explicitly listed as entirely unsupported or only partially supported by the framework.45 More fundamentally, ViewInspector is strictly engineered for unit testing the two-dimensional SwiftUI structural tree; it possesses zero capability to introspect the rendered three-dimensional scene contained inside a RealityKit ARView or RealityView. Therefore, while ViewInspector is an exceptionally fast and highly recommended tool for validating standard SwiftUI forms, navigation layers, and settings menus 33, it is architecturally incapable of serving as the primary validation engine for an AI testing the core functionality of a spatial RealityKit game.

## **Orchestrating the Autonomous Testing Pipeline with Claude Code**

With the semantic extraction layers established and the payload optimized via TOON compression, the final phase involves orchestrating the artificial intelligence agent to autonomously execute the testing protocols.

### **Agentic Coding Tools and System Configuration**

Claude Code operates as a fully-featured, agentic CLI coding tool capable of reading codebases, editing files, running local terminal commands, and deeply integrating with developer tools.46 To utilize Claude Code for autonomous macOS UI testing, developers can deploy the agent directly via native installation scripts, Homebrew (brew install \--cask claude-code), or WinGet, though the native installation is recommended as it automatically updates in the background.46

The critical integration point relies on configuring Claude Code to communicate with the semantic extraction servers. This is achieved by modifying the claude\_desktop\_config.json file to explicitly define the MCP servers. For instance, linking the macos-ui-automation-mcp requires declaring the path to the localized Python environment and the execution script, seamlessly granting Claude the capability to invoke native macOS commands directly.17

### **Semantic Routing and Subagent Delegation**

To maximize the efficiency of the testing process, the architecture should leverage advanced orchestration patterns, such as Semantic Routing and Subagent delegation. Tools like Semantic Router allow the primary LLM to rapidly determine the most efficient method to retrieve specific information based on the current context, choosing between querying the SQL database, pinging a REST API, or analyzing raw JSON output without wasting tokens on irrelevant calls.47

Within Claude Code, testing responsibilities can be modularized by creating project-specific subagents stored in the .claude/agents/ directory.48 By utilizing descriptive definition fields, the primary agent can automatically delegate specific testing tasks. For example, one subagent equipped solely with ViewInspector tools can be tasked with validating the 2D SwiftUI menus at lightning speed, while a separate subagent equipped with the macOS UI Automation MCP and TOON decoding tools focuses exclusively on verifying the spatial coordinates and complex states of the 3D RealityKit entities.48 By strictly limiting tool access to what each individual subagent actually needs, the overarching system avoids context exhaustion and drastically improves operational latency.48 Furthermore, utilizing Claude Code's "Plan Mode" allows the agent to construct a safe, step-by-step testing blueprint, ensuring that complex UI interactions are logically sequenced before arbitrary execution begins.48

### **The Optimal Autonomous Testing Architecture**

Based on the exhaustive synthesis of the available technological paradigms, the optimal architectural solution for empowering an MCP-compliant AI agent to autonomously test a hybrid macOS game built with SwiftUI and RealityKit involves a complete, permanent departure from vision-based utilities like Peekaboo. The following framework represents the fastest, most token-efficient, and highly deterministic pipeline currently achievable.

**Phase 1: Game Architecture Preparation (Semantic Instrumentation)**

Before the AI agent can autonomously test the game, the inherently invisible RealityKit entities must be forcibly rendered visible to the macOS operating system's semantic layer.

1. Every interactive ModelEntity rendering within the spatial RealityKit scene must be explicitly wrapped with a configured AccessibilityComponent.22  
2. Developers must assign a clear, semantic label to every object and apply accurate trait definitions, such as .button, to interactive elements.21  
3. The application must utilize the AccessibilityComponent.CustomContent property to publish proprietary internal game data—such as highly precise 3D spatial coordinates, health pools, inventory states, and collision physics flags—directly into the accessibility node, establishing a secure data pipeline to the LLM.22

**Phase 2: The MCP Server Configuration (Sensory Input)**

The AI agent requires a sensory input mechanism that completely bypasses pixel processing and screenshots.

1. Deploy an Accessibility MCP server that interfaces directly with the raw macOS AX tree. The macos-ui-automation-mcp is highly recommended, as it provides absolute programmatic control over the local OS UI, requiring only standard macOS accessibility permissions to operate.14 Alternatively, the OculOS binary can be executed in MCP mode to expose every UI element as a structured dataset.11  
2. The terminal executing Claude Code and the associated MCP server must be explicitly granted Accessibility and Screen Recording permissions within the macOS System Settings under Privacy & Security.11 Without this explicit authorization, the server can enumerate windows but remains strictly prohibited from traversing the deep UI hierarchy.

**Phase 3: Token Optimization (Data Middleware)**

To actively prevent the highly verbose macOS accessibility tree from overwhelming the LLM's context window, data serialization must be heavily optimized prior to transmission.

1. Configure the MCP server or an intermediary processing script to intercept the verbose JSON payload generated by the accessibility tree dump.  
2. Pass the raw JSON payload directly through a TOON encoder, utilizing tools such as toon-swift. This process will mathematically convert the deeply nested, punctuation-heavy JSON into a highly compact, indentation-based, tabular format.27  
3. Transmit the highly compressed TOON payload directly to Claude Code. This architectural step guarantees a token consumption reduction of up to 60 percent, drastically cutting inference time, reducing API overhead costs, and allowing the agent to retain a significantly longer historical context of the test suite.27

**Phase 4: Autonomous Execution (Agentic Loop)**

With highly dense, semantically perfect data seamlessly flowing into the context window, the AI agent can execute complex testing protocols with absolute autonomy.

1. Provide Claude Code with a system prompt detailing its explicit role as an automated QA engineer, supplying the necessary project-specific subagents and the comprehensive spec sheet detailing the game's spatial mechanics.48  
2. Claude Code autonomously queries the MCP server, receiving the TOON-compressed AX tree. It effortlessly reads the injected customContent of the RealityKit entities to perfectly understand the absolute 3D state of the application without requiring a single visual snapshot.23  
3. The agent calculates the required target interaction, formulating the precise accessibility coordinate. It transmits this command back through the MCP server, which executes the OS-level input natively via the Accessibility API.14 This deterministic loop repeats continuously, achieving high-speed, flawless autonomous testing.

By discarding visual estimation methodologies and rigorously adopting a programmatic, token-optimized semantic pipeline, engineering teams can fully realize the profound potential of autonomous AI testing in complex, spatial macOS environments.

#### **Works cited**

1. peekaboo | Skills Marketplace \- LobeHub, accessed March 3, 2026, [https://lobehub.com/es/skills/insight68-skills-peekaboo](https://lobehub.com/es/skills/insight68-skills-peekaboo)  
2. Peekaboo \- Mac automation that sees the screen and does the clicks. \- GitHub, accessed March 3, 2026, [https://github.com/steipete/Peekaboo](https://github.com/steipete/Peekaboo)  
3. macOS UI Automation Skill for Claude Code | Peekaboo \- MCP Market, accessed March 3, 2026, [https://mcpmarket.com/tools/skills/macos-ui-automation-peekaboo-1](https://mcpmarket.com/tools/skills/macos-ui-automation-peekaboo-1)  
4. Peekaboo 2.0 – Free the CLI from its MCP shackles | Peter Steinberger, accessed March 3, 2026, [https://steipete.me/posts/2025/peekaboo-2-freeing-the-cli-from-its-mcp-shackles](https://steipete.me/posts/2025/peekaboo-2-freeing-the-cli-from-its-mcp-shackles)  
5. Visual Agents at CVPR 2025 \- Voxel51, accessed March 3, 2026, [https://voxel51.com/blog/visual-agents-at-cvpr-2025](https://voxel51.com/blog/visual-agents-at-cvpr-2025)  
6. LLM Comparison: Key Concepts & Best Practices \- Nexla, accessed March 3, 2026, [https://nexla.com/ai-readiness/llm-comparison/](https://nexla.com/ai-readiness/llm-comparison/)  
7. Thoughts of LLM and Ui.Vision Integration Test \- General Discussion, accessed March 3, 2026, [https://forum.ui.vision/t/thoughts-of-llm-and-ui-vision-integration-test/26707](https://forum.ui.vision/t/thoughts-of-llm-and-ui-vision-integration-test/26707)  
8. Challenges and Considerations of Vision Agents in Automation | AskUI Blog, accessed March 3, 2026, [https://www.askui.com/blog-posts/challenges-vision-agents/index.html](https://www.askui.com/blog-posts/challenges-vision-agents/index.html)  
9. Making RealityKit apps accessible \- Create with Swift, accessed March 3, 2026, [https://www.createwithswift.com/making-realitykit-apps-accessible/](https://www.createwithswift.com/making-realitykit-apps-accessible/)  
10. \# DirectShell: I Turned the Accessibility Layer Into a Universal App ..., accessed March 3, 2026, [https://dev.to/tlrag/-directshell-i-turned-the-accessibility-layer-into-a-universal-app-interface-no-screenshots-no-2457](https://dev.to/tlrag/-directshell-i-turned-the-accessibility-layer-into-a-universal-app-interface-no-screenshots-no-2457)  
11. GitHub \- huseyinstif/oculos: If it's on the screen, it's an API. Control any desktop app via REST \+ MCP. Rust., accessed March 3, 2026, [https://github.com/huseyinstif/oculos](https://github.com/huseyinstif/oculos)  
12. MacPaw/macapptree: Repository for macos accessibility ... \- GitHub, accessed March 3, 2026, [https://github.com/MacPaw/macapptree](https://github.com/MacPaw/macapptree)  
13. iOS Accessibility Inspector in Your Terminal \- LDomaradzki.com, accessed March 3, 2026, [https://ldomaradzki.com/blog/xctree-accessibility-cli](https://ldomaradzki.com/blog/xctree-accessibility-cli)  
14. mb-dev/macos-ui-automation-mcp \- GitHub, accessed March 3, 2026, [https://github.com/mb-dev/macos-ui-automation-mcp](https://github.com/mb-dev/macos-ui-automation-mcp)  
15. Sharing my new Mac Automation MCP \- Reddit, accessed March 3, 2026, [https://www.reddit.com/r/mcp/comments/1mfi63s/sharing\_my\_new\_mac\_automation\_mcp/](https://www.reddit.com/r/mcp/comments/1mfi63s/sharing_my_new_mac_automation_mcp/)  
16. iosef | MCP Servers \- LobeHub, accessed March 3, 2026, [https://lobehub.com/mcp/riwsky-iosef](https://lobehub.com/mcp/riwsky-iosef)  
17. AutoMac MCP | MCP Servers \- LobeHub, accessed March 3, 2026, [https://lobehub.com/mcp/digithree-automac-mcp](https://lobehub.com/mcp/digithree-automac-mcp)  
18. How to interact with 3D objects in RealityKit \- Stack Overflow, accessed March 3, 2026, [https://stackoverflow.com/questions/56932621/how-to-interact-with-3d-objects-in-realitykit](https://stackoverflow.com/questions/56932621/how-to-interact-with-3d-objects-in-realitykit)  
19. Creating 3D entities with RealityKit | Apple Developer Documentation, accessed March 3, 2026, [https://developer.apple.com/documentation/visionOS/creating-3d-entities-with-realitykit](https://developer.apple.com/documentation/visionOS/creating-3d-entities-with-realitykit)  
20. iOS/Swift: RealityKit \- Component Entity System | by Itsuki \- Medium, accessed March 3, 2026, [https://medium.com/@itsuki.enjoy/ios-swift-realitykit-component-entity-system-ba031496c1fc](https://medium.com/@itsuki.enjoy/ios-swift-realitykit-component-entity-system-ba031496c1fc)  
21. Create accessible spatial experiences | Documentation \- WWDC Notes, accessed March 3, 2026, [https://wwdcnotes.com/documentation/wwdcnotes/wwdc23-10034-create-accessible-spatial-experiences/](https://wwdcnotes.com/documentation/wwdcnotes/wwdc23-10034-create-accessible-spatial-experiences/)  
22. AccessibilityComponent | Apple Developer Documentation, accessed March 3, 2026, [https://developer.apple.com/documentation/RealityKit/AccessibilityComponent/](https://developer.apple.com/documentation/RealityKit/AccessibilityComponent/)  
23. Improving the Accessibility of RealityKit Apps | Apple Developer Documentation, accessed March 3, 2026, [https://developer.apple.com/documentation/realitykit/improving-the-accessibility-of-realitykit-apps](https://developer.apple.com/documentation/realitykit/improving-the-accessibility-of-realitykit-apps)  
24. customContent | Apple Developer Documentation, accessed March 3, 2026, [https://developer.apple.com/documentation/realitykit/accessibilitycomponent/customcontent-swift.property](https://developer.apple.com/documentation/realitykit/accessibilitycomponent/customcontent-swift.property)  
25. I Built a Tool That Lets You Point at iOS Views and Tell AI What to Change | by Ertem Biyik, accessed March 3, 2026, [https://medium.com/@ertembiyik/i-built-a-tool-that-lets-you-point-at-ios-views-and-tell-ai-what-to-change-ebfea007fa37](https://medium.com/@ertembiyik/i-built-a-tool-that-lets-you-point-at-ios-views-and-tell-ai-what-to-change-ebfea007fa37)  
26. TOON vs JSON: A Token-Optimized Data Format for Reducing LLM Costs \- Tensorlake, accessed March 3, 2026, [https://www.tensorlake.ai/blog/toon-vs-json](https://www.tensorlake.ai/blog/toon-vs-json)  
27. 🚀 TOON (Token-Oriented Object Notation) — The Smarter, Lighter JSON for LLMs \- DEV Community, accessed March 3, 2026, [https://dev.to/abhilaksharora/toon-token-oriented-object-notation-the-smarter-lighter-json-for-llms-2f05](https://dev.to/abhilaksharora/toon-token-oriented-object-notation-the-smarter-lighter-json-for-llms-2f05)  
28. toon-format/toon-swift: 🐦‍🔥 Community-driven Swift implementation of TOON \- GitHub, accessed March 3, 2026, [https://github.com/toon-format/toon-swift](https://github.com/toon-format/toon-swift)  
29. TOON is terrible, so I invented a new format (TRON) to prove a point : r/LocalLLaMA \- Reddit, accessed March 3, 2026, [https://www.reddit.com/r/LocalLLaMA/comments/1pa3ok3/toon\_is\_terrible\_so\_i\_invented\_a\_new\_format\_tron/](https://www.reddit.com/r/LocalLLaMA/comments/1pa3ok3/toon_is_terrible_so_i_invented_a_new_format_tron/)  
30. Hands-on XCUITest Features with Xcode 9 \- Superagentic AI Blog, accessed March 3, 2026, [https://shashikantjagtap.net/hands-xcuitest-features-xcode-9/](https://shashikantjagtap.net/hands-xcuitest-features-xcode-9/)  
31. Thirty Seconds to Pass: Performance Comparison of iOS UI Testing Frameworks, accessed March 3, 2026, [https://devexperts.com/blog/ios-ui-testing-frameworks-performance-comparison/](https://devexperts.com/blog/ios-ui-testing-frameworks-performance-comparison/)  
32. Appium vs XCUITest : Key Differences \- BrowserStack, accessed March 3, 2026, [https://www.browserstack.com/guide/appium-vs-xcuitest](https://www.browserstack.com/guide/appium-vs-xcuitest)  
33. XCUITest: How to Write UI Tests for SwiftUI Apps \- swiftyplace, accessed March 3, 2026, [https://www.swiftyplace.com/blog/xcuitest-ui-testing-swiftui?utm\_source=rss\&utm\_medium=rss\&utm\_campaign=xcuitest-ui-testing-swiftui](https://www.swiftyplace.com/blog/xcuitest-ui-testing-swiftui?utm_source=rss&utm_medium=rss&utm_campaign=xcuitest-ui-testing-swiftui)  
34. XCUI Test: app.debugDescription shows info of the last screen \- Stack Overflow, accessed March 3, 2026, [https://stackoverflow.com/questions/45336144/xcui-test-app-debugdescription-shows-info-of-the-last-screen](https://stackoverflow.com/questions/45336144/xcui-test-app-debugdescription-shows-info-of-the-last-screen)  
35. How to parse the string content of debugDescription in XCUITest swift \- Stack Overflow, accessed March 3, 2026, [https://stackoverflow.com/questions/75293048/how-to-parse-the-string-content-of-debugdescription-in-xcuitest-swift](https://stackoverflow.com/questions/75293048/how-to-parse-the-string-content-of-debugdescription-in-xcuitest-swift)  
36. Understanding XCUITest screenshots and how to access them, accessed March 3, 2026, [https://rderik.com/blog/understanding-xcuitest-screenshots-and-how-to-access-them/](https://rderik.com/blog/understanding-xcuitest-screenshots-and-how-to-access-them/)  
37. Appium vs XCUITest — Which Mobile Test Automation Tool Is Right for You? \- Medium, accessed March 3, 2026, [https://medium.com/@girish.chauhan.pro/appium-vs-xcuitest-which-mobile-test-automation-tool-is-right-for-you-2812a5f1ea24](https://medium.com/@girish.chauhan.pro/appium-vs-xcuitest-which-mobile-test-automation-tool-is-right-for-you-2812a5f1ea24)  
38. appium/appium-mac2-driver: Next-gen Appium macOS driver, backed by Apple XCTest \- GitHub, accessed March 3, 2026, [https://github.com/appium/appium-mac2-driver](https://github.com/appium/appium-mac2-driver)  
39. Appium vs. XCUITest for Automated iOS Testing \- SmartBear, accessed March 3, 2026, [https://smartbear.com/blog/appium-vs-xcuitest-for-automated-ios-testing/](https://smartbear.com/blog/appium-vs-xcuitest-for-automated-ios-testing/)  
40. How popular is ViewInspector for SwiftUI testing? Do you use it? : r/Xcode \- Reddit, accessed March 3, 2026, [https://www.reddit.com/r/Xcode/comments/1oezjgs/how\_popular\_is\_viewinspector\_for\_swiftui\_testing/](https://www.reddit.com/r/Xcode/comments/1oezjgs/how_popular_is_viewinspector_for_swiftui_testing/)  
41. How ViewInspector Unlocks SwiftUI Testing \- Quality Coding, accessed March 3, 2026, [https://qualitycoding.org/viewinspector-swiftui-testing/](https://qualitycoding.org/viewinspector-swiftui-testing/)  
42. Testing SwiftUI Views with XCTest: The Definitive Guide | by Neeshu Kumar | Medium, accessed March 3, 2026, [https://medium.com/@thakurneeshu280/testing-swiftui-views-with-xctest-the-definitive-guide-dbc78596fc65](https://medium.com/@thakurneeshu280/testing-swiftui-views-with-xctest-the-definitive-guide-dbc78596fc65)  
43. nalexn/ViewInspector: Runtime introspection and unit testing of SwiftUI views \- GitHub, accessed March 3, 2026, [https://github.com/nalexn/ViewInspector](https://github.com/nalexn/ViewInspector)  
44. ViewInspector/guide.md at 0.10.4 \- GitHub, accessed March 3, 2026, [https://github.com/nalexn/ViewInspector/blob/0.10.4/guide.md](https://github.com/nalexn/ViewInspector/blob/0.10.4/guide.md)  
45. ViewInspector for SwiftUI Testing | by James Ryu | Feb, 2026 \- Medium, accessed March 3, 2026, [https://medium.com/@jamesryu/viewinspector-for-swiftui-testing-969bcb6ae383](https://medium.com/@jamesryu/viewinspector-for-swiftui-testing-969bcb6ae383)  
46. Claude Code overview \- Claude Code Docs, accessed March 3, 2026, [https://code.claude.com/docs/en/overview](https://code.claude.com/docs/en/overview)  
47. How to Build an AI Agent With Semantic Router and LLM Tools \- The New Stack, accessed March 3, 2026, [https://thenewstack.io/how-to-build-an-ai-agent-with-semantic-router-and-llm-tools/](https://thenewstack.io/how-to-build-an-ai-agent-with-semantic-router-and-llm-tools/)  
48. Common workflows \- Claude Code Docs, accessed March 3, 2026, [https://code.claude.com/docs/en/common-workflows](https://code.claude.com/docs/en/common-workflows)