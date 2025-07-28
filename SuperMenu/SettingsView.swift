import SwiftUI
internal import UniformTypeIdentifiers
import ServiceManagement

struct SettingsView: View {
    @AppStorage("shouldCleanupDMGs") private var shouldCleanupDMGs: Bool = false
    @AppStorage("autoDMGEnabled") private var autoDMGEnabled: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @AppStorage("superShortcutEnabled") private var superShortcutEnabled: Bool = false
    @AppStorage("isToDoListEnabled") private var isToDoListEnabled: Bool = true
    @AppStorage("shouldPromptBeforeTaskDeletion") private var shouldPromptBeforeTaskDeletion: Bool = true
    @AppStorage("isDiskManagementEnabled") private var isDiskManagementEnabled: Bool = true
    @AppStorage("areDeveloperToolsEnabled") private var areDeveloperToolsEnabled: Bool = false
    @AppStorage("isCURLTestEnabled") private var isCURLTestEnabled: Bool = false
    @AppStorage("showWarningBeforePortKill") private var showWarningBeforePortKill: Bool = true
    
    let appDelegate = AppDelegate()

    @State private var superShortcutBindings: [String: URL] = {
        if let data = UserDefaults.standard.data(forKey: "superShortcutBindings"),
           let decoded = try? JSONDecoder().decode([String: URL].self, from: data) {
            return decoded
        }
        return [:]
    }()

    @State private var newKey: String = ""
    @State private var hasAccessibilityPermission = AXIsProcessTrusted()

    @StateObject private var clipboardManager = ClipboardManager.shared

    private func saveSuperShortcutBindings() {
        if let data = try? JSONEncoder().encode(superShortcutBindings) {
            UserDefaults.standard.set(data, forKey: "superShortcutBindings")
        }
    }

    var body: some View {
        VStack {
            TabView {
                VStack(alignment: .leading) {
                    Form {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, newValue in
                                if newValue {
                                    try? SMAppService.mainApp.register()
                                } else {
                                    try? SMAppService.mainApp.unregister()
                                }
                            }
                    }
                    .padding()
                    Spacer()
                }
                .tabItem {
                    Text("General")
                }
                
                VStack(alignment: .leading) {
                    Form {
                        Toggle("Automatically clean up DMGs after install", isOn: $shouldCleanupDMGs)
                        Toggle("Auto-install DMGs from Downloads", isOn: $autoDMGEnabled)
                    }
                    .padding()
                    Spacer()
                }
                .tabItem {
                    Text("Apps")
                }
                
                VStack(alignment: .leading) {
                    Form {
                        Toggle("Disk Management Enabled", isOn: $isDiskManagementEnabled)
                    }
                    .padding()
                    Spacer()
                }
                .tabItem {
                    Text("Disks")
                }
                
                VStack(alignment: .leading) {
                    if !hasAccessibilityPermission {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accessibility permission is required to detect Super Shortcuts. (If the error persists click About > Refresh Permissions)")
                                .foregroundColor(.red)
                            Button("Open System Preferences") {
                                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                                NSWorkspace.shared.open(url)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                    Form {
                        Toggle("Enable Super Shortcut", isOn: $superShortcutEnabled)
                            .onChange(of: superShortcutEnabled) { _, _ in
                                (NSApp.delegate as? AppDelegate)?.updateSuperShortcutMonitoring()
                            }
                        Text("""
                    Each shortcut requires ⌘ + ⌥ + ⌃ + ⇧ plus a key.
                    
                    Tip: Use Raycast’s Hyper Key setting to map Caps Lock to all modifiers. When held, pressing a key sends ⌘⌥⇧⌃ + key, which will trigger your Super Shortcut.
                    """)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        ForEach(superShortcutBindings.sorted(by: { $0.key < $1.key }), id: \.key) { key, url in
                            HStack {
                                Text("⌘⌥⌃⇧\(key.uppercased())")
                                Spacer()
                                Text(url.lastPathComponent)
                                Button("Open") {
                                    NSWorkspace.shared.open(url)
                                }
                                Button("Remove") {
                                    superShortcutBindings.removeValue(forKey: key)
                                    saveSuperShortcutBindings()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                            .padding(7)
                        }
                        
                        HStack {
                            TextField("Key", text: $newKey)
                                .frame(width: 50)
                            Button("Pick Application") {
                                guard newKey.count == 1 else { return }
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.allowedContentTypes = [.application]
                                if panel.runModal() == .OK, let url = panel.url {
                                    superShortcutBindings[newKey.lowercased()] = url
                                    saveSuperShortcutBindings()
                                    newKey = ""
                                }
                            }
                        }
                        //Disabled temporarily
                        if false {
                            HStack {
                                TextField("Key", text: $newKey)
                                    .frame(width: 50)
                                Button("Pick Shell Script") {
                                    guard newKey.count == 1 else { return }
                                    let panel = NSOpenPanel()
                                    panel.allowsMultipleSelection = false
                                    panel.allowedContentTypes = [.shellScript]
                                    if panel.runModal() == .OK, let url = panel.url {
                                        do {
                                            let chmodProcess = Process()
                                            chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
                                            chmodProcess.arguments = ["+x", url.path]
                                            try chmodProcess.run()
                                            chmodProcess.waitUntilExit()
                                        } catch {
                                            print("Failed to make script executable via chmod: \(error)")
                                        }
                                        superShortcutBindings[newKey.lowercased()] = URL(fileURLWithPath: "/bin/zsh -c \"\(url.deletingLastPathComponent().path)/./\(url.lastPathComponent)\"")
                                        saveSuperShortcutBindings()
                                        newKey = ""
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    Spacer()
                }
                .tabItem {
                    Text("Super Shortcut")
                }
                .onAppear {
                    hasAccessibilityPermission = AXIsProcessTrusted()
                }
                
                VStack(alignment: .leading) {
                    Form {
                        Toggle("Enable Clipboard Monitoring", isOn: $clipboardManager.isMonitoring)
                        Button("Clear Clipboard History") {
                            clipboardManager.history.removeAll()
                        }
                        .foregroundColor(.red)
                        
                        if clipboardManager.history.isEmpty {
                            Text("No clipboard history.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(clipboardManager.history, id: \.self) { item in
                                Text(item)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                    .padding()
                    Spacer()
                }
                .tabItem {
                    Text("Clipboard")
                }
                
                VStack(alignment: .leading) {
                    Form {
                        Toggle("To-Do List Enabled", isOn: $isToDoListEnabled)
                        if isToDoListEnabled {
                            Toggle("Show Alert Before Deleting Task", isOn: $shouldPromptBeforeTaskDeletion)
                        }
                    }
                }
                .tabItem {
                    Text("To-Do List")
                }
                
                VStack(alignment: .leading) {
                    Form {
                        Section {
                            Toggle("Enable Developer Tools", isOn: $areDeveloperToolsEnabled)
                        }
                        if areDeveloperToolsEnabled {
                            Section {
                                Text("Port Management")
                                Toggle("Warn Before Killing Ports", isOn: $showWarningBeforePortKill)
                            }
                        }
                    }
                }
                .tabItem {
                    Text("Dev Tools")
                }
                
                VStack(alignment: .leading) {
                    Form {
                        Section(header: Text("About")) {
                            Text("Made by Liam Reynolds")
                        }
                        Section(header: Text("Recommended Productivity Apps")) {
                            HStack {
                                Image(systemName: "sparkles")
                                Link("Raycast", destination: URL(string: "https://www.raycast.com/")!)
                                    .lineLimit(nil)
                            }
                            
                            Label {
                                Link("Clop", destination: URL(string: "https://lowtechguys.com/clop/")!)
                            } icon: {
                                Image(systemName: "bag.circle")
                            }
                            
                            Label {
                                Link("App Cleaner & Uninstaller", destination: URL(string: "https://freemacsoft.net/appcleaner/")!)
                            } icon: {
                                Image(systemName: "trash")
                            }
                            
                            Text("I am not associated with these applications. They are just personal recommendations.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Section(header: Text("Github")) {
                            Link("View SuperMenu on GitHub", destination: URL(string: "https://github.com/Doyboy1005152/SuperMenu")!)
                            Link("Developer GitHub Profile", destination: URL(string: "https://github.com/Doyboy1005152")!)
                        }
                        Section(header: Text("Permissions")) {
                            Button("Refresh Permissions") {
                                _ = Bundle.main.bundlePath
                                let appId = Bundle.main.bundleIdentifier ?? ""
                                
                                let script = """
                            do shell script "tccutil reset Accessibility \(appId)"
                            """
                                
                                var error: NSDictionary?
                                if let scriptObject = NSAppleScript(source: script) {
                                    scriptObject.executeAndReturnError(&error)
                                }
                                
                                // Reopen the accessibility system preferences page
                                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                    .padding()
                    Spacer()
                }
                .tabItem {
                    Text("About")
                }
            }
            Text("Most Changes Will Take Place Upon Restarting the App")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}
