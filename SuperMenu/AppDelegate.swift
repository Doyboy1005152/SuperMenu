import AppKit
import Carbon
import Combine
import ServiceManagement
import SwiftUI
internal import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var runningProcesses = [Process]()
    let currentVersion = 1
    @AppStorage("shouldCleanupDMGs") var shouldCleanupDMGs: Bool = false
    @AppStorage("isDiskManagementEnabled") var isDiskManagementEnabled: Bool = true
    @AppStorage("isClipboardHistoryEnabled") var isClipboardHistoryEnabled: Bool = true
    @AppStorage("isToDoListEnabled") var isToDoListEnabled: Bool = true
    @AppStorage("areDeveloperToolsEnabled") var areDevToolsEnabled: Bool = false
    @AppStorage("webRequestTestingEnabled") var webRequestTestingEnabled: Bool = true
    @State var firstRun: Bool = true

    var clipboardHistoryWindow: NSWindow?
    var settingsWindow: NSWindow?
    var toDoListWindow: NSWindow?
    var cURLWindow: NSWindow?
    var portsWindow: NSWindow?
    var HTTPTestWindow: NSWindow?
    var JWTDecoderWindow: NSWindow?

    // Script shortcut bindings stored in UserDefaults
    var scriptShortcutBindings: [String: URL] {
        get {
            if let data = UserDefaults.standard.data(forKey: "scriptShortcutBindings"),
               let bindings = try? JSONDecoder().decode([String: URL].self, from: data) {
                return bindings
            }
            return [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "scriptShortcutBindings")
            }
        }
    }

    // Window to show update progress
    var updateWindow: NSWindow?

    // Published update message for progress window
    @Published var updateMessage: String = "Checking for updates..."

    var superShortcutEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "superShortcutEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "superShortcutEnabled") }
    }

    var superShortcutMonitor: Any?
    var superShortcutURLMonitor: Any?
    var superShortcutScriptMonitor: Any?
    var statusItems = [NSStatusItem]()

    @objc func showSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Settings"
        window.contentView = NSHostingView(
            rootView: SettingsView()
                .frame(minWidth: 1200, minHeight: 500)
                .padding()
        )
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc func showClipboardHistory() {
        if let window = clipboardHistoryWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.title = "Clipboard History"
        newWindow.contentView = NSHostingView(rootView: ClipboardHistoryView())
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        clipboardHistoryWindow = newWindow
    }

    @objc func openCURLWindow() {
        if let window = cURLWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.title = "API/cURL Request Test"
        newWindow.contentView = NSHostingView(rootView: CURLView())
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        cURLWindow = newWindow
    }

    @objc func openJWTDecoderWindow() {
        if let window = JWTDecoderWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "JWT Decoder"
        window.contentView = NSHostingView(
            rootView: JWTDecoderView()
                .frame(minWidth: 1200, minHeight: 500)
                .padding()
        )
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        JWTDecoderWindow = window
    }

    @objc func openPortsWindow() {
        if let window = portsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Ports"
        window.contentView = NSHostingView(
            rootView: PortsView()
                .frame(minWidth: 1200, minHeight: 500)
                .padding()
        )
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        portsWindow = window
    }

    var statusItem: NSStatusItem?
    var hotKeyRef: EventHotKeyRef?
    var autoDMGEnabled: Bool = true
    var dmgWatcherSource: DispatchSourceFileSystemObject?
    var processedDMGs: Set<URL> = []

    override init() {
        super.init()
        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, eventRef, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout.size(ofValue: hotKeyID), nil, &hotKeyID)
            if hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    (NSApp.delegate as? AppDelegate)?.ejectAllDisks()
                }
                return noErr
            }
            if hotKeyID.id == 2 {
                DispatchQueue.main.async {
                    (NSApp.delegate as? AppDelegate)?.showClipboardHistory()
                }
                return noErr
            }
            return noErr
        }, 1, [eventSpec], nil, nil)
    }

    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appPath = Bundle.main.bundlePath
        print("App path: \(appPath)")

        if !checkAccessibilityPermissions() {
            print("Accessibility permission is required for global keyboard shortcuts. Please enable it in System Preferences → Security & Privacy → Privacy → Accessibility.")
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()

        statusItem?.menu = menu

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "SuperMenu")
            button.image?.isTemplate = true
            button.action = #selector(menuButtonClicked)
        }

        let diskMenu = NSMenu(title: "Disk Management")
        let diskItem = NSMenuItem(title: "Disk Management", action: nil, keyEquivalent: "")
        diskItem.submenu = diskMenu

        if isDiskManagementEnabled {
            menu.addItem(diskItem)
        }
        let ejectAllDisksItem = NSMenuItem(title: "Eject All Disks", action: #selector(ejectAllDisks), keyEquivalent: "")
        ejectAllDisksItem.target = self
        diskMenu.addItem(ejectAllDisksItem)

        let disksSubmenu = NSMenu(title: "Disks")
        let disksMenuItem = NSMenuItem(title: "Disks", action: nil, keyEquivalent: "")
        disksMenuItem.submenu = disksSubmenu
        diskMenu.addItem(disksMenuItem)

        let refreshItem = NSMenuItem(title: "Refresh Disks", action: #selector(refreshDisks(_:)), keyEquivalent: "")
        refreshItem.target = self
        disksSubmenu.addItem(refreshItem)
        disksSubmenu.addItem(NSMenuItem.separator())

        populateDisksSubmenu(disksSubmenu)

        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["list", "-plist"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
               let dict = plist as? [String: Any],
               let disks = dict["AllDisksAndPartitions"] as? [[String: Any]] {
                for disk in disks {
                    if let device = disk["DeviceIdentifier"] as? String {
                        var title = device
                        if let content = disk["Content"] as? String, content != "Apple_partition_scheme" {
                            if let volumeName = disk["VolumeName"] as? String {
                                title = "\(volumeName) (\(device))"
                            } else if let apfsVolumes = disk["APFSVolumes"] as? [[String: Any]],
                                      let firstVolume = apfsVolumes.first,
                                      let apfsName = firstVolume["VolumeName"] as? String {
                                title = "\(apfsName) (\(device))"
                            }
                        }
                        let diskItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                        disksSubmenu.addItem(diskItem)
                    }
                }
            }
        } catch {
            print("Error listing disks for submenu: \(error)")
        }

        let devToolsSubmenu = NSMenu(title: "Dev Tools")
        let devToolsItem = NSMenuItem(title: "Dev Tools", action: nil, keyEquivalent: "")
        devToolsItem.submenu = devToolsSubmenu
        if areDevToolsEnabled {
            menu.addItem(devToolsItem)
            if webRequestTestingEnabled {
                let webRequestMenu = NSMenu(title: "Web Request Tests")
                let webRequestItem = NSMenuItem(title: "Web Request Tests", action: nil, keyEquivalent: "")
                webRequestItem.submenu = webRequestMenu
                devToolsSubmenu.addItem(webRequestItem)
                let cURLTestItem = NSMenuItem(title: "cURL", action: #selector(openCURLWindow), keyEquivalent: "")
                cURLTestItem.target = self
                webRequestMenu.addItem(cURLTestItem)
                let HTTPTestItem = NSMenuItem(title: "HTTP", action: #selector(showHTTPTestWindow), keyEquivalent: "")
                webRequestMenu.addItem(HTTPTestItem)
            }

            let portCheckingItem = NSMenuItem(title: "Port Management", action: #selector(openPortsWindow), keyEquivalent: "")
            devToolsSubmenu.addItem(portCheckingItem)

            let JWTDecoderItem = NSMenuItem(title: "JWT Decoder", action: #selector(openJWTDecoderWindow), keyEquivalent: "")
            devToolsSubmenu.addItem(JWTDecoderItem)

            let UUIDItem = NSMenuItem(title: "Generate UUID & Copy to Clipboard", action: #selector(generateUUID), keyEquivalent: "")
            devToolsSubmenu.addItem(UUIDItem)
        }

        let openSettingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettingsWindow), keyEquivalent: ",")
        openSettingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(openSettingsItem)

        let clipboardMenuItem = NSMenuItem(title: "Clipboard History", action: #selector(showClipboardHistory), keyEquivalent: "")
        clipboardMenuItem.target = self
        menu.addItem(clipboardMenuItem)

        let toDoListItem = NSMenuItem(title: "To-Do List", action: #selector(showToDoList), keyEquivalent: "")
        toDoListItem.target = self
        menu.addItem(toDoListItem)

        let aboutItem = NSMenuItem(title: "About Me", action: #selector(openPortfolio), keyEquivalent: "")
        menu.addItem(aboutItem)

        let privacyItem = NSMenuItem(title: "Privacy Policy", action: #selector(openPrivacyPolicy), keyEquivalent: "")
        menu.addItem(privacyItem)
        
        let makeWindowsProminentItem = NSMenuItem(title: "Make This App's Windows Prominent", action: #selector(showAllWindows), keyEquivalent: "")
        menu.addItem(makeWindowsProminentItem)

        menu.addItem(NSMenuItem(title: "Quit SuperMenu", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu

        let hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: "eHot".hashValue)), id: 1)
        let modifierFlags: UInt32 = UInt32(controlKey + optionKey + cmdKey + shiftKey)
        let keyCode: UInt32 = 14 // Key code for "E"
        RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)

        // Register clipboard history hotkey: Control+Option+Command+Shift+V
        let hotKeyID2 = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: "cHist".hashValue)), id: 2)
        let keyCode2: UInt32 = 9 // Key code for "V"
        RegisterEventHotKey(keyCode2, modifierFlags, hotKeyID2, GetEventDispatcherTarget(), 0, &hotKeyRef)

        if #available(macOS 13.0, *) {
            do {
                try SMAppService.loginItem(identifier: "com.example.SuperMenuLauncher").register()
            } catch {
                print("Failed to register login item: \(error)")
            }
        } else {
            SMLoginItemSetEnabled("com.example.SuperMenuLauncher" as CFString, true)
        }

        if autoDMGEnabled {
            watchDownloadsForDMG()
        }

        updateSuperShortcutMonitoring()
    }

    @objc func showToDoList() {
        if let window = toDoListWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "To-Do List"
        window.contentView = NSHostingView(rootView: ToDoListView())
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        toDoListWindow = window
    }

    @objc func generateUUID() {
        let UUIDString = UUID().uuidString

        // Copy the UUID to the clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(UUIDString, forType: .string)

        SmallPopover.showCenteredMessage("Copied to clipboard (:")
    }

    @objc func showHTTPTestWindow() {
        if let window = HTTPTestWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "HTTP Request Testing"
        window.contentView = NSHostingView(rootView: HTTPView())
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        toDoListWindow = window
    }

    func populateDisksSubmenu(_ menu: NSMenu) {
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["list", "-plist"]
        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
               let dict = plist as? [String: Any],
               let disks = dict["AllDisksAndPartitions"] as? [[String: Any]] {
                for disk in disks {
                    if let device = disk["DeviceIdentifier"] as? String {
                        var title = device
                        if let content = disk["Content"] as? String, content != "Apple_partition_scheme" {
                            if let volumeName = disk["VolumeName"] as? String {
                                title = "\(volumeName) (\(device))"
                            } else if let apfsVolumes = disk["APFSVolumes"] as? [[String: Any]],
                                      let firstVolume = apfsVolumes.first,
                                      let apfsName = firstVolume["VolumeName"] as? String {
                                title = "\(apfsName) (\(device))"
                            }
                        }
                        let diskItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                        menu.addItem(diskItem)
                    }
                }
            }
        } catch {
            print("Error listing disks for submenu: \(error)")
        }
    }

    @objc func refreshDisks(_ sender: NSMenuItem) {
        if let submenu = sender.menu {
            submenu.removeAllItems()

            let refreshItem = NSMenuItem(title: "Refresh Disks", action: #selector(refreshDisks(_:)), keyEquivalent: "")
            refreshItem.target = self
            submenu.addItem(refreshItem)
            submenu.addItem(NSMenuItem.separator())

            populateDisksSubmenu(submenu)
        }
    }

    func updateSuperShortcutMonitoring() {
        // Remove existing monitors if any
        if let monitor = superShortcutURLMonitor {
            NSEvent.removeMonitor(monitor)
            superShortcutURLMonitor = nil
        }
        if let monitor = superShortcutScriptMonitor {
            NSEvent.removeMonitor(monitor)
            superShortcutScriptMonitor = nil
        }
        if let monitor = superShortcutMonitor {
            NSEvent.removeMonitor(monitor)
            superShortcutMonitor = nil
        }

        // Add local monitor to suppress system beep for super shortcut keys
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let requiredFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            if flags == requiredFlags {
                return nil // suppress system beep
            }
            return event
        }

        guard superShortcutEnabled else { return }

        // Global monitor for URL launch shortcuts
        superShortcutURLMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let requiredFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            if flags == requiredFlags {
                let pressedKey = event.charactersIgnoringModifiers?.lowercased() ?? ""
                if let data = UserDefaults.standard.data(forKey: "superShortcutBindings"),
                   let bindings = try? JSONDecoder().decode([String: URL].self, from: data),
                   let url = bindings[pressedKey] {
                    print("Launching URL shortcut for key: \(pressedKey) -> \(url)")
                    NSWorkspace.shared.open(url)
                }
            }
        }

        // Global monitor for script execution shortcuts
        superShortcutScriptMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let requiredFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            if flags == requiredFlags {
                let pressedKey = event.charactersIgnoringModifiers?.lowercased() ?? ""
                if let scriptURL = self.scriptShortcutBindings[pressedKey] {
                    print("Executing script shortcut for key: \(pressedKey) at path: \(scriptURL.path)")
                    self.runningProcesses = []
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/bin/bash")
                    task.arguments = [scriptURL.path]
                    task.standardOutput = Pipe()
                    task.standardError = Pipe()

                    self.runningProcesses.append(task)

                    do {
                        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
                        try task.run()

                        DispatchQueue.global().async {
                            task.waitUntilExit()
                            DispatchQueue.main.async {
                                if let index = self.runningProcesses.firstIndex(of: task) {
                                    self.runningProcesses.remove(at: index)
                                }
                            }
                        }
                    } catch {
                        print("Failed to execute script at \(scriptURL.path): \(error)")
                    }
                }
            }
        }
    }

    @objc func openPrivacyPolicy() {
        
    }

    @objc func openPortfolio() {
        
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
            sender.state = .off
        } else {
            try? SMAppService.mainApp.register()
            sender.state = .on
        }
    }

    @objc func menuButtonClicked() {
        
    }
    
    @objc func showAllWindows() {
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func ejectAllDisks() {
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["list", "-plist"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
        } catch {
            print("Failed to list disks: \(error)")
            return
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any],
              let disks = dict["AllDisksAndPartitions"] as? [[String: Any]] else {
            print("Failed to parse diskutil output")
            return
        }
        print("--- Disk List ---")
        for disk in disks {
            print(disk)
        }
        print("--- End Disk List ---")
        var ejectedAny = false
        for disk in disks {
            guard let device = disk["DeviceIdentifier"] as? String else { continue }

            // Check volumes under this disk
            if let volumes = disk["APFSVolumes"] as? [[String: Any]] {
                for volume in volumes {
                    if let mountPoint = volume["MountPoint"] as? String,
                       mountPoint.hasPrefix("/Volumes/"),
                       let _ = volume["DeviceIdentifier"] as? String {
                        let ejectTask = Process()
                        ejectTask.launchPath = "/usr/sbin/diskutil"
                        ejectTask.arguments = ["eject", device]

                        do {
                            try ejectTask.run()
                            ejectTask.waitUntilExit()
                            if ejectTask.terminationStatus == 0 {
                                print("Ejected \(device)")
                                ejectedAny = true
                            } else {
                                print("Failed to eject \(device)")
                            }
                        } catch {
                            print("Failed to eject \(device): \(error)")
                        }

                        break
                    }
                }
            }
        }
        if !ejectedAny {
            print("No ejectable disks found.")
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    @objc func toggleAutoDMG(_ sender: NSMenuItem) {
        autoDMGEnabled.toggle()
        sender.state = autoDMGEnabled ? .on : .off
        if autoDMGEnabled {
            watchDownloadsForDMG()
        } else {
            dmgWatcherSource?.cancel()
            dmgWatcherSource = nil
        }
    }

    func watchDownloadsForDMG() {
        guard autoDMGEnabled else { return }
        print("Started watching Downloads folder for DMG files")
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileDescriptor = open(downloadsURL.path, O_EVTONLY)
        if fileDescriptor == -1 {
            print("Failed to open Downloads folder for monitoring")
            return
        }
        let queue = DispatchQueue.global()
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: [.write, .extend], queue: queue)

        source.setEventHandler {
            print("Downloads folder changed")
            let contents = (try? FileManager.default.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: nil)) ?? []
            for fileURL in contents where fileURL.pathExtension == "dmg" {
                if !self.processedDMGs.contains(fileURL) {
                    self.processedDMGs.insert(fileURL)
                    self.handleDMG(fileURL)
                }
            }
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        dmgWatcherSource = source
    }

    func handleDMG(_ dmgURL: URL) {
        let mountTask = Process()
        mountTask.launchPath = "/usr/bin/hdiutil"
        mountTask.arguments = ["attach", dmgURL.path, "-nobrowse", "-quiet"]

        let mountPipe = Pipe()
        mountTask.standardOutput = mountPipe
        do {
            try mountTask.run()
            mountTask.waitUntilExit()
        } catch {
            print("Failed to mount DMG: \(error)")
            return
        }

        var copiedApps: [URL] = []

        // Find mounted volumes
        let volumes = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes")
        volumes?.forEach { volumeName in
            let volumePath = "/Volumes/\(volumeName)"
            if let apps = try? FileManager.default.contentsOfDirectory(atPath: volumePath) {
                for app in apps where app.hasSuffix(".app") {
                    let sourceURL = URL(fileURLWithPath: volumePath).appendingPathComponent(app)
                    let destURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(app)
                    do {
                        try FileManager.default.copyItem(at: sourceURL, to: destURL)
                        copiedApps.append(destURL)
                        print("Copied \(app) to /Applications")
                    } catch {
                        print("Failed to copy \(app): \(error)")
                    }
                }
            }

            // Cleanup logic
            if shouldCleanupDMGs {
                // Detach volume
                let detachTask = Process()
                detachTask.launchPath = "/usr/bin/hdiutil"
                detachTask.arguments = ["detach", volumePath, "-quiet"]
                try? detachTask.run()

                // Optionally delete the DMG file after use
                try? FileManager.default.removeItem(at: dmgURL)
            }
        }

        if !copiedApps.isEmpty {
            DispatchQueue.main.async {
                let appName = copiedApps[0].lastPathComponent
                let alert = NSAlert()
                alert.messageText = "\(appName) moved to Applications."
                alert.informativeText = "Would you like to open the application now?"
                alert.addButton(withTitle: "Open Application")
                alert.addButton(withTitle: "OK")
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(copiedApps[0])
                }
            }
        }
    }
}
