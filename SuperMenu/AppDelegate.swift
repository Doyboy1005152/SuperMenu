import SwiftUI
import Carbon
import Combine
import ServiceManagement
import AppKit
internal import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @AppStorage("shouldCleanupDMGs") var shouldCleanupDMGs: Bool = false
    var settingsWindow: NSWindow?
    var clipboardHistoryWindow: NSWindow?
    
    var superShortcutEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "superShortcutEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "superShortcutEnabled") }
    }
    
    var superShortcutMonitor: Any?
    
    @objc func showSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.setFrameAutosaveName("Settings")
        newWindow.title = "Settings"
        newWindow.contentView = NSHostingView(rootView: SettingsView())
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = newWindow
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

    var statusItem: NSStatusItem?
    var hotKeyRef: EventHotKeyRef?
    var autoDMGEnabled: Bool = true
    var dmgWatcherSource: DispatchSourceFileSystemObject?
    var processedDMGs: Set<URL> = []

    override init() {
        super.init()
        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { (_, eventRef, userData) -> OSStatus in
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

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "SuperMenu")
            button.image?.isTemplate = true
            button.action = #selector(menuButtonClicked)
        }

        let menu = NSMenu()
        let ejectAllDisksItem = NSMenuItem(title: "Eject All Disks", action: #selector(ejectAllDisks), keyEquivalent: "")
        menu.addItem(ejectAllDisksItem)

        let openSettingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettingsWindow), keyEquivalent: ",")
        openSettingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(openSettingsItem)

        menu.addItem(NSMenuItem(title: "Quit SuperMenu", action: #selector(quit), keyEquivalent: "q"))

        let aboutItem = NSMenuItem(title: "About Me", action: #selector(openPortfolio), keyEquivalent: "")
        menu.addItem(aboutItem)

        let privacyItem = NSMenuItem(title: "Privacy Policy", action: #selector(openPrivacyPolicy), keyEquivalent: "")
        menu.addItem(privacyItem)

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
    
    func updateSuperShortcutMonitoring() {
        if let monitor = superShortcutMonitor {
            NSEvent.removeMonitor(monitor)
            superShortcutMonitor = nil
        }

        if superShortcutEnabled {
            superShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let requiredFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
                if flags.contains(requiredFlags) {
                    let pressedKey = event.charactersIgnoringModifiers?.lowercased() ?? ""
                    if let data = UserDefaults.standard.data(forKey: "superShortcutBindings"),
                       let bindings = try? JSONDecoder().decode([String: URL].self, from: data),
                       let url = bindings[pressedKey] {
                        print("Launching \(url)")
                        NSWorkspace.shared.open(url)
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
        // You may want to show the main menu or perform another action here.
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
                       let  _ = volume["DeviceIdentifier"] as? String {

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
