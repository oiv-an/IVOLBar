import AppKit
import ApplicationServices

struct AppRecord {
    let pid: pid_t
    let id: String
    let name: String
    let path: String
}
struct Scan {
    var hidden = Set<String>()
    var allowed = Set<String>()
    var protectedPIDs: [pid_t] = []
    var lines: [String] = []
}

func axValue(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
    return result
}
func frames(_ pid: pid_t) -> [CGRect]? {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.6)
    guard let value = axValue(app, "AXExtrasMenuBar"), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    let bar = value as! AXUIElement
    guard let children = axValue(bar, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
    var result: [CGRect] = []
    for child in children {
        guard let p = axValue(child, kAXPositionAttribute), let s = axValue(child, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size),
              size.width > 0, size.height > 0 else { return nil }
        result.append(CGRect(origin: point, size: size))
    }
    return result
}

final class Controller: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let defaults = UserDefaults.standard
    var divider: NSStatusItem!
    var arrow: NSStatusItem!
    var assertion: Any?
    var knownBundleIDs = Set<String>()
    var busy = false
    var generation = 0
    var autoHide = false
    var deadline = Date.distantFuture
    var retryAfter = Date.distantPast
    var timer: Timer?
    var menuOpen = false
    var lastError = ""
    let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/IVOLBar.log")
    var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let duplicates = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "pro.ivol.bar")
        guard duplicates.count <= 1 else { NSApp.terminate(nil); return }
        defaults.register(defaults: ["autoHide": false, "delay": 5.0])
        autoHide = defaults.bool(forKey: "autoHide")
        arrow = NSStatusBar.system.statusItem(withLength: 26)
        arrow.autosaveName = "IVOLBar.arrow"
        divider = NSStatusBar.system.statusItem(withLength: 18)
        divider.autosaveName = "IVOLBar.divider"
        divider.button?.title = "│"
        divider.button?.toolTip = "Слева — всегда видно. Между полоской и стрелкой — скрывается. ⌘ + перетаскивание."
        arrow.button?.toolTip = "Скрыть/раскрыть среднюю группу. Правая кнопка — настройки."
        for item in [divider!, arrow!] {
            item.button?.target = self
            item.button?.action = #selector(clicked(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateArrow()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                            object: nil, queue: .main) { [weak self] notification in
            guard let self, self.assertion != nil || self.busy,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleURL?.pathExtension == "app", let id = app.bundleIdentifier,
                  !self.knownBundleIDs.contains(id) else { return }
            // The restriction is bundle-based: a known app/helper restarting changes nothing.
            // Only a new bundle needs a rescan, so its icon is not accidentally restricted.
            self.log("Новое приложение: \(id); пересчёт группы")
            self.expand()
        })
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.willSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.expand() })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                               object: nil, queue: .main) { [weak self] _ in self?.expand() })
        log("Запуск \(Bundle.main.bundlePath); AX=\(AXIsProcessTrusted()); native=\(IVVisibilityAvailable())")
        if !defaults.bool(forKey: "introduced") {
            defaults.set(true, forKey: "introduced")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.instructions() }
        }
        resetDeadline()
    }

    func log(_ text: String) {
        let data = Data("\(ISO8601DateFormatter().string(from: Date())) \(text)\n".utf8)
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) { FileManager.default.createFile(atPath: logURL.path, contents: nil) }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
    func updateArrow() { arrow.button?.title = busy ? "…" : (assertion == nil ? "‹" : "›") }
    func resetDeadline() { deadline = Date().addingTimeInterval(max(2, defaults.double(forKey: "delay"))) }
    func pointerInMenuBar() -> Bool {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            let height = max(28, screen.frame.maxY - screen.visibleFrame.maxY)
            return p.x >= screen.frame.minX && p.x <= screen.frame.maxX && p.y >= screen.frame.maxY - height && p.y <= screen.frame.maxY
        }
    }
    func tick() {
        if pointerInMenuBar() || menuOpen || NSEvent.pressedMouseButtons != 0 || NSEvent.modifierFlags.contains(.command) {
            resetDeadline(); return
        }
        if autoHide && assertion == nil && !busy && Date() >= deadline && Date() >= retryAfter { collapse(manual: false) }
    }
    @objc func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp || sender === divider.button { showMenu(); return }
        if assertion != nil || busy { expand() } else { collapse(manual: true) }
    }
    func expand() {
        generation += 1
        if let a = assertion { IVReleaseVisibility(a) }
        assertion = nil
        knownBundleIDs.removeAll()
        busy = false
        retryAfter = .distantPast
        updateArrow()
        resetDeadline()
        log("Раскрыто")
    }
    func fail(_ message: String, manual: Bool) {
        expand()
        lastError = message
        // Back off without silently changing the user's auto-hide preference.
        retryAfter = Date().addingTimeInterval(30)
        log("ОТКАЗ: \(message)")
        if manual { alert(message) }
    }
    func collapse(manual: Bool) {
        guard assertion == nil && !busy else { return }
        guard AXIsProcessTrusted() else {
            if manual {
                let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(opts)
            }
            fail("Разрешите IVOL Bar управление интерфейсом в настройках конфиденциальности macOS. Затем повторите нажатие стрелки.", manual: manual)
            return
        }
        guard IVVisibilityAvailable() else {
            fail("Механизм скрытия недоступен.", manual: manual); return
        }
        let records = NSWorkspace.shared.runningApplications.compactMap { app -> AppRecord? in
            guard let id = app.bundleIdentifier else { return nil }
            return AppRecord(pid: app.processIdentifier, id: id, name: app.localizedName ?? id, path: app.bundleURL?.path ?? "")
        }
        let own = Bundle.main.bundleIdentifier ?? "pro.ivol.bar"
        knownBundleIDs = Set(records.map(\.id))
        busy = true
        generation += 1
        let token = generation
        updateArrow()
        DispatchQueue.global(qos: .userInitiated).async {
            let beforeHosted = hostedItems()
            let ownItems = (beforeHosted ?? []).filter { $0.owner == own }
            // AppKit status-item windows can refer to the inactive/notched display.
            // Both items have different fixed widths (divider 18, arrow 26 + host padding).
            let pairs = Dictionary(grouping: ownItems, by: \.display).compactMap { display, items -> (Int, CGRect, CGRect)? in
                guard items.count == 2 else { return nil }
                let sorted = items.sorted { $0.frame.width < $1.frame.width }
                let left = sorted[0].frame, right = sorted[1].frame
                guard right.width - left.width > 4, left.maxX <= right.minX + 2 else { return nil }
                return (display, left, right)
            }
            guard let pair = pairs.max(by: { $0.2.minX - $0.1.maxX < $1.2.minX - $1.1.maxX }) else {
                DispatchQueue.main.async {
                    guard self.generation == token else { return }
                    self.fail("Не найдена строка меню с полоской слева от стрелки. Расставьте границы с ⌘ на используемом мониторе.", manual: manual)
                }
                return
            }
            let (display, left, right) = pair
            let activeItems = (beforeHosted ?? []).filter { $0.display == display }
            var scan = Scan()
            var outside = Set<String>()
            for app in records {
                scan.allowed.insert(app.id)
                guard app.id != own, !app.id.hasPrefix("com.apple."), app.path.hasSuffix(".app") else { continue }
                let positions = activeItems.filter { $0.owner == app.id }.map(\.frame)
                guard !positions.isEmpty else {
                    outside.insert(app.id)
                    scan.lines.append("UNKNOWN keep \(app.id) \(app.path)")
                    continue
                }
                // Boundaries and items now come from the same host window/display.
                let middle = positions.allSatisfy { $0.minX >= left.maxX - 2 && $0.maxX <= right.minX + 2 }
                if middle { scan.hidden.insert(app.id) }
                else { outside.insert(app.id); scan.protectedPIDs.append(app.pid) }
                scan.lines.append("\(middle ? "HIDE" : "KEEP") \(app.id) \(positions)")
            }
            scan.hidden.subtract(outside)
            scan.allowed.subtract(scan.hidden)
            scan.allowed.insert(own)
            let result = scan
            DispatchQueue.main.async {
                guard self.generation == token else { return }
                self.log("Границы \(left) / \(right)\n" + result.lines.joined(separator: "\n"))
                let mismatches = records.filter { app in
                    guard result.protectedPIDs.contains(app.pid) else { return false }
                    let resolved = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id)?.resolvingSymlinksInPath().path
                    return resolved != URL(fileURLWithPath: app.path).resolvingSymlinksInPath().path
                }
                for app in mismatches {
                    self.log("IDENTITY MISMATCH \(app.id): running=\(app.path); resolved=\(NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id)?.path ?? "nil")")
                }
                guard let beforeHosted else {
                    self.fail("Не удалось прочитать системную строку меню для проверки результата. Скрытие отменено.", manual: manual)
                    return
                }
                let protectedOwners = Set(beforeHosted.map(\.owner)).subtracting(result.hidden)
                guard !result.hidden.isEmpty else {
                    self.fail("Между полоской и стрелкой нет приложений, которые можно уверенно скрыть. Перетащите туда значки с ⌘. Нераспознанные и системные значки оставляются видимыми.", manual: manual)
                    return
                }
                guard mismatches.isEmpty else {
                    self.fail("macOS находит другую установленную копию: \(mismatches.map(\.name).joined(separator: ", ")). Скрытие отменено во избежание потери значков.", manual: manual)
                    return
                }
                IVActivateVisibility(Array(result.allowed).sorted()) { a, error in
                    guard self.generation == token else { if let a { IVReleaseVisibility(a) }; return }
                    guard let a, error == nil else { self.fail(error ?? "Ошибка скрытия", manual: manual); return }
                    self.assertion = a
                    self.busy = false
                    self.lastError = ""
                    self.retryAfter = .distantPast
                    self.updateArrow()
                    self.log("Запрос принят macOS (\(manual ? "ручное скрытие" : "автоскрытие")): скрыть=\(result.hidden.sorted()); оставить=\(protectedOwners.sorted()). AX не доказывает видимость — нужна проверка изображения.")
                    if ProcessInfo.processInfo.environment["IVOLBAR_DIAGNOSTIC"] == "1" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            guard self.generation == token else { return }
                            self.log("Диагностический таймер: восстановление через 5 секунд")
                            self.expand()
                        }
                        return
                    }
                    // Hidden host nodes retain stale frames on macOS 27. Do not use
                    // their presence as evidence that the native restriction failed.
                }
            }
        }
    }
    func alert(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "IVOL Bar"
        alert.informativeText = message
        alert.addButton(withTitle: "Понятно")
        menuOpen = true
        alert.runModal()
        menuOpen = false
        resetDeadline()
    }
    @objc func instructions() {
        alert("Всегда видно  │  скрываемые значки  ‹  всегда видно\n\nЗажмите ⌘ и расположите полоску левее стрелки. Перетаскивайте значки между ними — только эта группа скрывается. Нажатие стрелки скрывает/раскрывает; правая кнопка открывает настройки.\n\nАвтоскрытие изначально выключено для безопасной настройки. Его можно включить в меню. Системные значки остаются видимыми. Если у приложения несколько значков и хотя бы один находится снаружи, остаётся видимым всё приложение.")
    }
    @objc func toggleAuto() {
        autoHide.toggle()
        defaults.set(autoHide, forKey: "autoHide")
        resetDeadline()
        log("Автоскрытие=\(autoHide)")
    }
    @objc func setDelay(_ sender: NSMenuItem) { defaults.set(Double(sender.tag), forKey: "delay"); resetDeadline() }
    @objc func reveal() { expand() }
    @objc func openLog() { NSWorkspace.shared.open(logURL) }
    @objc func quit() { expand(); NSApp.terminate(nil) }
    func menuWillOpen(_ menu: NSMenu) { menuOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuOpen = false; resetDeadline() }
    func showMenu() {
        let menu = NSMenu()
        menu.delegate = self
        func add(_ title: String, _ selector: Selector) -> NSMenuItem {
            let item = menu.addItem(withTitle: title, action: selector, keyEquivalent: "")
            item.target = self
            return item
        }
        _ = add("Показать всё", #selector(reveal))
        let auto = add("Автоскрытие после ухода мыши", #selector(toggleAuto))
        auto.state = autoHide ? .on : .off
        let delay = NSMenuItem(title: "Задержка", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for seconds in [3, 5, 10, 30] {
            let item = sub.addItem(withTitle: "\(seconds) секунд", action: #selector(setDelay(_:)), keyEquivalent: "")
            item.tag = seconds; item.target = self
            item.state = defaults.integer(forKey: "delay") == seconds ? .on : .off
        }
        delay.submenu = sub; menu.addItem(delay)
        menu.addItem(.separator())
        _ = add("Как пользоваться", #selector(instructions))
        _ = add("Открыть диагностику", #selector(openLog))
        if !lastError.isEmpty { let item = NSMenuItem(title: "Последняя ошибка: \(lastError)", action: nil, keyEquivalent: ""); menu.addItem(item) }
        _ = add("Завершить IVOL Bar", #selector(quit))
        if let button = arrow.button { menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button) }
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let a = assertion { IVReleaseVisibility(a) }
        timer?.invalidate()
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let controller = Controller()
application.delegate = controller
application.run()
