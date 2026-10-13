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
    var lines: [String] = []
    // Kept apps running outside /Applications: macOS 27 hides them anyway.
    var outsideApplications: [String] = []
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
    var trackedOwners = Set<AppInstance>()
    var busy = false
    var generation = 0
    var autoHide = false
    var deadline = Date.distantFuture
    var retryAfter = Date.distantPast
    var timer: Timer?
    var menuOpen = false
    var lastError = ""
    var locationWarning = ""
    let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/IVOLBar.log")
    var observers: [NSObjectProtocol] = []
    var configuringGroup = false {
        didSet { defaults.set(configuringGroup, forKey: "configuringGroup") }
    }
    var displaySettlesAfter = Date.distantPast
    var recoveryPending = false
    var displaysSleeping = false
    var recoveryDeadline: TimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let duplicates = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "pro.ivol.bar")
        guard duplicates.count <= 1 else { NSApp.terminate(nil); return }
        defaults.register(defaults: ["autoHide": false, "delay": 5.0])
        autoHide = defaults.bool(forKey: "autoHide")
        configuringGroup = defaults.bool(forKey: "configuringGroup")
        createStatusItems()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        installObservers()
        log("Запуск \(Bundle.main.bundlePath); AX=\(AXIsProcessTrusted()); native=\(IVVisibilityAvailable())")
        if !defaults.bool(forKey: "introduced") {
            defaults.set(true, forKey: "introduced")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.instructions() }
        }
        displaySettlesAfter = Date().addingTimeInterval(5)
        resetDeadline()
    }

    func createStatusItems() {
        arrow = NSStatusBar.system.statusItem(withLength: 26)
        arrow.autosaveName = "IVOLBar.arrow"
        divider = NSStatusBar.system.statusItem(withLength: 18)
        divider.autosaveName = "IVOLBar.divider"
        divider.button?.title = "│"
        divider.button?.toolTip = "Слева от │ — скрывать, справа — оставлять видимым. Перемещение с ⌘."
        arrow.button?.toolTip = "Скрыть/раскрыть значки слева от полоски. Стрелка не является границей. Правая кнопка — настройки."
        for item in [divider!, arrow!] {
            item.button?.target = self
            item.button?.action = #selector(clicked(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateArrow()
    }

    func installObservers() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                            object: nil, queue: .main) { [weak self] notification in
            guard let self, self.assertion != nil || self.busy,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleURL?.pathExtension == "app", let id = app.bundleIdentifier,
                  let instance = AppInstance(app) else { return }
            let replacingOwner = self.trackedOwners.contains { $0.bundleID == id && $0 != instance }
            guard replacingOwner || !self.knownBundleIDs.contains(id) else { return }
            // Known helpers with no hosted icon must not repeatedly reveal the bar.
            self.log("Запуск экземпляра: \(id) pid=\(instance.pid); замена владельца=\(replacingOwner)")
            self.expand()
        })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                            object: nil, queue: .main) { [weak self] notification in
            guard let self, self.assertion != nil || self.busy,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  self.trackedOwners.contains(where: { $0.pid == app.processIdentifier && $0.bundleID == app.bundleIdentifier }) else { return }
            self.log("Владелец значка завершён: pid=\(app.processIdentifier); удаление старых привязок")
            self.expand()
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.displaysSleeping = true
                self?.displayChanged()
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.displaysSleeping = false
                self?.displayChanged()
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                               object: nil, queue: .main) { [weak self] _ in self?.displayChanged() })
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
        if recoveryPending || displaysSleeping {
            resetDeadline()
            guard !displaysSleeping, ProcessInfo.processInfo.systemUptime >= recoveryDeadline,
                  !NSScreen.screens.isEmpty, !configuringGroup, !menuOpen,
                  !pointerInMenuBar(), NSEvent.pressedMouseButtons == 0,
                  !NSEvent.modifierFlags.contains(.command) else { return }
            rebuildStatusItems()
            return
        }
        if configuringGroup || Date() < displaySettlesAfter || pointerInMenuBar() || menuOpen || NSEvent.pressedMouseButtons != 0 || NSEvent.modifierFlags.contains(.command) {
            resetDeadline(); return
        }
        if autoHide && assertion == nil && !busy && Date() >= deadline && Date() >= retryAfter { collapse(manual: false) }
    }
    @objc func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp || sender === divider.button { showMenu(); return }
        if assertion != nil || busy { expand() } else { collapse(manual: true) }
    }
    func displayChanged() {
        // Debounce display reconnection; never rebuild while the displays sleep.
        recoveryPending = true
        recoveryDeadline = ProcessInfo.processInfo.systemUptime + 10
        displaySettlesAfter = Date().addingTimeInterval(10)
        expand()
        log("Экран изменился: восстановление элементов после 10 секунд стабильности; сон=\(displaysSleeping)")
    }
    func rebuildStatusItems() {
        recoveryPending = false
        expand()
        // Removing/recreating one item can overwrite the other's saved position.
        // Snapshot both before touching either, then restore before assigning names.
        let positionKeys = ["NSStatusItem Preferred Position IVOLBar.arrow",
                            "NSStatusItem Preferred Position IVOLBar.divider"]
        let positions = positionKeys.compactMap { key in defaults.object(forKey: key).map { (key, $0) } }
        for item in [arrow!, divider!] {
            item.autosaveName = nil
            NSStatusBar.system.removeStatusItem(item)
        }
        arrow = nil
        divider = nil
        for (key, value) in positions { defaults.set(value, forKey: key) }
        createStatusItems()
        displaySettlesAfter = Date().addingTimeInterval(2)
        resetDeadline()
        log("Элементы IVOL Bar пересозданы после стабилизации экранов; группа и настройки сохранены")
    }
    func expand() {
        generation += 1
        if let a = assertion { IVReleaseVisibility(a) }
        assertion = nil
        knownBundleIDs.removeAll()
        trackedOwners.removeAll()
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
    func collapse(manual: Bool, captureGroup: Bool = false) {
        guard assertion == nil && !busy else { return }
        guard !recoveryPending, !displaysSleeping, Date() >= displaySettlesAfter else { return }
        if configuringGroup && !captureGroup {
            if manual { alert("Выберите «Закончить расстановку» в меню.") }
            return
        }
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
        // Never apply historical membership outside the visible boundaries.
        // Display recovery is debounced above; scan only while expanded.
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
                guard right.width - left.width > 4 else { return nil }
                return (display, left, right)
            }
            guard let pair = pairs.max(by: { a, b in
                (beforeHosted ?? []).filter { $0.display == a.0 }.count <
                (beforeHosted ?? []).filter { $0.display == b.0 }.count
            }) else {
                DispatchQueue.main.async {
                    guard self.generation == token else { return }
                    self.fail("Не удалось определить полоску │ в строке меню. Скрытие отменено; повторите после стабилизации экрана.", manual: manual)
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
                let positions = activeItems.filter { $0.owner == app.id && $0.instance.pid == app.pid }.map(\.frame)
                guard !positions.isEmpty else {
                    outside.insert(app.id)
                    scan.lines.append("UNKNOWN keep \(app.id) \(app.path)")
                    continue
                }
                // Boundaries and items now come from the same host window/display.
                let middle = positions.allSatisfy { $0.maxX <= left.minX + 2 }
                if middle { scan.hidden.insert(app.id) }
                else {
                    outside.insert(app.id)
                    if !app.path.hasPrefix("/Applications/") { scan.outsideApplications.append(app.name) }
                }
                scan.lines.append("\(middle ? "HIDE" : "KEEP") \(app.id) pid=\(app.pid) path=\(app.path) \(positions)")
            }
            scan.hidden.subtract(outside)
            // Use one coherent menu bar. Inactive/notched displays can retain
            // stale or clipped frames and must not veto this display's selection.
            scan.allowed.subtract(scan.hidden)
            scan.allowed.insert(own)
            let result = scan
            DispatchQueue.main.async {
                guard self.generation == token else { return }
                self.log("Экран host=\(display); одна граница \(left); стрелка \(right) — только управление\n" + result.lines.joined(separator: "\n"))
                let names = Array(Set(result.outsideApplications)).sorted()
                self.locationWarning = names.isEmpty ? "" : "Запущены не из /Applications, macOS скроет их всё равно: " + names.joined(separator: ", ")
                if !names.isEmpty { self.log("ПРЕДУПРЕЖДЕНИЕ: \(self.locationWarning)") }
                self.activate(result, beforeHosted: beforeHosted, token: token, manual: manual, captureGroup: captureGroup)
            }
        }
    }
    func activate(_ result: Scan, beforeHosted: [HostedItem]?, token: Int, manual: Bool, captureGroup: Bool = false) {
        guard generation == token else { return }
        guard let beforeHosted else {
            self.fail("Не удалось прочитать системную строку меню для проверки результата. Скрытие отменено.", manual: manual)
            return
        }
        let owners = Set(beforeHosted.map(\.instance))
        guard owners.allSatisfy({ $0.isCurrent }) else {
            fail("Владелец значка сменился во время чтения. Повторите скрытие после запуска приложения.", manual: manual)
            return
        }
        trackedOwners = owners
        let protectedOwners = Set(beforeHosted.map(\.owner)).subtracting(result.hidden)
        guard !result.hidden.isEmpty else {
            busy = false
            if captureGroup { configuringGroup = false }
            retryAfter = Date().addingTimeInterval(5)
            updateArrow()
            log("Слева от полоски нет подтверждённых кандидатов: скрытие не применяется")
            if manual { alert("На выбранной строке меню слева от полоски │ не найдены приложения с определяемым положением. Нужные значки переносите с ⌘ вправо от полоски, остальные оставляйте слева. Для расчёта используется экран с наибольшим числом обнаруженных элементов.") }
            return
        }
        // Include owners hosted by MenuBarAgent even if Workspace omitted them.
        let allowed = result.allowed.union(protectedOwners)
        IVActivateVisibility(Array(allowed).sorted()) { a, error in
            guard self.generation == token else { if let a { IVReleaseVisibility(a) }; return }
            guard let a, error == nil else { self.fail(error ?? "Ошибка скрытия", manual: manual); return }
            guard owners.allSatisfy({ $0.isCurrent }) else {
                IVReleaseVisibility(a)
                self.expand()
                self.log("Смена владельца во время применения: устаревшее ограничение снято")
                return
            }
            self.assertion = a
            self.busy = false
            self.lastError = ""
            self.retryAfter = .distantPast
            self.updateArrow()
            if captureGroup {
                self.configuringGroup = false
                self.log("Расстановка завершена: \(result.hidden.sorted())")
            }
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
    @objc func beginGroupConfiguration() {
        configuringGroup = true
        expand()
        alert("Автоскрытие временно приостановлено. С ⌘ перенесите нужные значки вправо от полоски │. Всё, что слева, будет скрываться. Стрелка — только кнопка раскрытия, её положение не влияет на выбор. Затем выберите «Закончить расстановку».")
    }
    @objc func saveGroupConfiguration() { collapse(manual: true, captureGroup: true) }
    @objc func cancelGroupConfiguration() {
        configuringGroup = false
        resetDeadline()
    }
    @objc func resetSettings() {
        NSApp.activate(ignoringOtherApps: true)
        let confirmation = NSAlert()
        confirmation.alertStyle = .warning
        confirmation.messageText = "Сбросить IVOL Bar?"
        confirmation.informativeText = "Будут удалены настройки IVOL Bar. Все значки раскроются.\n\nНа macOS 27 положение стрелки и полоски хранит сама система, поэтому на строке меню они могут остаться на прежних местах. Положения других приложений и разрешения macOS не изменятся. После сброса перенесите нужные значки вправо от │ и выберите «Закончить расстановку». До этого автоскрытие приостановлено, в том числе после перезапуска. Затем задержка составит 5 секунд."
        confirmation.addButton(withTitle: "Отмена")
        confirmation.addButton(withTitle: "Сбросить")
        menuOpen = true
        let response = confirmation.runModal()
        menuOpen = false
        resetDeadline()
        guard response == .alertSecondButtonReturn else { return }

        configuringGroup = true
        expand() // Invalidates pending callbacks and releases the native restriction.
        for item in [arrow!, divider!] {
            item.autosaveName = nil
            NSStatusBar.system.removeStatusItem(item)
        }
        arrow = nil
        divider = nil
        // Clear after removal: AppKit can write positions while removing an item.
        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "pro.ivol.bar")
        defaults.set(true, forKey: "autoHide")
        defaults.set(5.0, forKey: "delay")
        defaults.set(true, forKey: "introduced")
        configuringGroup = true
        autoHide = true
        lastError = ""
        createStatusItems()
        displaySettlesAfter = Date().addingTimeInterval(2)
        resetDeadline()
        log("Сброшены настройки и собственные позиции IVOL Bar; ожидание новой расстановки")
        alert("Сброс выполнен. С ⌘ перенесите Cataloger и другие нужные значки вправо от полоски │, скрываемые оставьте слева. Затем выберите «Закончить расстановку». До этого значки не будут автоматически сворачиваться.")
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
        alert("Скрываемые значки → │ → всегда видимые значки.\n\nРаскройте всё стрелкой. С ⌘ перенесите нужные значки вправо от полоски, остальные оставьте слева. Нажмите стрелку — левая часть скроется. Стрелка не является второй границей и может стоять с любой стороны. Список отдельно сохранять не нужно.\n\nДля расстановки без таймера выберите «Настроить группу по расположению…», затем «Закончить расстановку». Системные значки и IVOL Bar остаются доступными. Если хотя бы один значок приложения справа, всё приложение остаётся разрешённым. При неизвестном положении скрытие этого приложения не применяется.")
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
        if configuringGroup {
            _ = add("Закончить расстановку", #selector(saveGroupConfiguration))
            _ = add("Отменить настройку группы", #selector(cancelGroupConfiguration))
        } else {
            _ = add("Настроить группу по расположению…", #selector(beginGroupConfiguration))
        }
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
        _ = add("Сбросить настройки и расстановку IVOL Bar…", #selector(resetSettings))
        if !lastError.isEmpty { let item = NSMenuItem(title: "Последняя ошибка: \(lastError)", action: nil, keyEquivalent: ""); menu.addItem(item) }
        if !locationWarning.isEmpty { menu.addItem(NSMenuItem(title: locationWarning, action: nil, keyEquivalent: "")) }
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
