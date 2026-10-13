import AppKit
import ApplicationServices

// A bundle identifier is not a running-instance identity. PID reuse must not
// attach a new process to an old menu-bar snapshot.
struct AppInstance: Hashable {
    let pid: pid_t
    let bundleID: String
    let launchedAt: Date?
    let executablePath: String

    init?(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier else { return nil }
        pid = app.processIdentifier
        bundleID = id
        launchedAt = app.launchDate
        executablePath = app.executableURL?.path ?? ""
    }

    var isCurrent: Bool {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated,
              let current = AppInstance(app) else { return false }
        return self == current
    }
}

// Read the host tree, not a client's stale AXExtrasMenuBar geometry.
struct HostedItem {
    let instance: AppInstance
    var owner: String { instance.bundleID }
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
    func owners(_ element: AXUIElement, depth: Int) -> Set<AppInstance> {
        guard depth < 4 else { return [] }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid != agent.processIdentifier,
           let app = NSRunningApplication(processIdentifier: pid),
           let instance = AppInstance(app) { return [instance] }
        if axValue(element, kAXRoleAttribute) as? String == kAXApplicationRole { return [] }
        return (axValue(element, kAXChildrenAttribute) as? [AXUIElement] ?? [])
            .reduce(into: Set<AppInstance>()) { $0.formUnion(owners($1, depth: depth + 1)) }
    }
    for window in roots where axValue(window, kAXRoleAttribute) as? String == kAXWindowRole {
        defer { display += 1 }
        guard let children = axValue(window, kAXChildrenAttribute) as? [AXUIElement] else { continue }
        for group in children {
            guard let v = axValue(group, "AXFrame"), CFGetTypeID(v) == AXValueGetTypeID() else { continue }
            var frame = CGRect.zero
            guard AXValueGetValue(v as! AXValue, .cgRect, &frame), frame.width > 0 else { continue }
            for instance in owners(group, depth: 0) {
                result.append(HostedItem(instance: instance, frame: frame, display: display))
            }
        }
    }
    return result.isEmpty ? nil : result
}
