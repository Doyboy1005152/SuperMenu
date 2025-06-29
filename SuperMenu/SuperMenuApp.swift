import AppKit
import Carbon
import Combine
import ServiceManagement
import SwiftUI
internal import UniformTypeIdentifiers

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var isMonitoring: Bool = true {
        didSet {
            if isMonitoring {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    @Published var history: [String] = []
    private var changeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?

    private init() {
        if isMonitoring {
            startMonitoring()
        }
    }

    private func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        if pb.changeCount != changeCount {
            changeCount = pb.changeCount
            if let copiedString = pb.string(forType: .string), !copiedString.isEmpty {
                if history.first != copiedString {
                    history.insert(copiedString, at: 0)
                    if history.count > 50 {
                        history.removeLast()
                    }
                }
            }
        }
    }

    func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

struct ClipboardHistoryView: View {
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Clipboard History")
                .font(.headline)
                .padding()

            List {
                ForEach(clipboardManager.history, id: \.self) { item in
                    HStack {
                        Text(item)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .onTapGesture {
                                clipboardManager.copyToClipboard(item)
                                presentationMode.wrappedValue.dismiss()
                            }
                        Button("Remove") {
                            if let i = clipboardManager.history.firstIndex(where: { $0 == item }) {
                                clipboardManager.history.remove(at: i)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 300, minHeight: 400)
        }
    }
}

@main
struct SuperMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showProgressPopover: Bool = false

    var body: some Scene {
        WindowGroup("Settings") {
            SettingsView()
        }.commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NSApp.sendAction(#selector(AppDelegate.showSettingsWindow), to: nil, from: nil)
                }.keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage("shouldCleanupDMGs") private var shouldCleanupDMGs: Bool = false
    @AppStorage("autoDMGEnabled") private var autoDMGEnabled: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @AppStorage("superShortcutEnabled") private var superShortcutEnabled: Bool = false

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
                Text("DMG")
            }

            VStack(alignment: .leading) {
                if !hasAccessibilityPermission {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accessibility permission is required to detect Super Shortcuts.")
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
                            Text("⌘\(key.uppercased())")
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
                }
                .padding()
                Spacer()
            }
            .tabItem {
                Text("About")
            }
        }
        .frame(width: 400, height: 200)
    }
}
