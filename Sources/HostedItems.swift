import AppKit
import ApplicationServices

// Read the host tree, not a client's stale AXExtrasMenuBar geometry.
struct HostedItem {
    let owner: String
    let frame: CGRect
    let display: Int
}

func hostedItems() -> [HostedItem]? {
    guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first else { return nil }
    let root = AXUIElementCreateApplication(agent.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 0.6)
    guard let roots = axValue(root, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
    var result: [HostedItem] = []
    var display = 0
    func owners(_ element: AXUIElement, depth: Int) -> Set<String> {
        guard depth < 4 else { return [] }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid != agent.processIdentifier,
           let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier { return [id] }
        if axValue(element, kAXRoleAttribute) as? String == kAXApplicationRole { return [] }
        return (axValue(element, kAXChildrenAttribute) as? [AXUIElement] ?? [])
            .reduce(into: Set<String>()) { $0.formUnion(owners($1, depth: depth + 1)) }
    }
    for window in roots where axValue(window, kAXRoleAttribute) as? String == kAXWindowRole {
        defer { display += 1 }
        guard let children = axValue(window, kAXChildrenAttribute) as? [AXUIElement] else { continue }
        for group in children {
            guard let v = axValue(group, "AXFrame"), CFGetTypeID(v) == AXValueGetTypeID() else { continue }
            var frame = CGRect.zero
            guard AXValueGetValue(v as! AXValue, .cgRect, &frame), frame.width > 0 else { continue }
            for owner in owners(group, depth: 0) { result.append(HostedItem(owner: owner, frame: frame, display: display)) }
        }
    }
    return result.isEmpty ? nil : result
}
