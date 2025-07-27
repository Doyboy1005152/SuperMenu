import SwiftUI

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

extension String {
    func toInt() -> Int? {
        return Int(self.filter { $0.isNumber })
    }
}
