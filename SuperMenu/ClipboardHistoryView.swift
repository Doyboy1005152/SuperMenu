import SwiftUI

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
                        Spacer()
                        Button("Copy") {
                            clipboardManager.copyToClipboard(item)
                            presentationMode.wrappedValue.dismiss()
                        }
                        Button("View") {
                            let detailWindow = NSWindow(
                                contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                                styleMask: [.titled, .closable, .resizable],
                                backing: .buffered,
                                defer: false
                            )
                            detailWindow.isReleasedWhenClosed = false
                            detailWindow.center()
                            detailWindow.title = "Clipboard Item"
                            detailWindow.contentView = NSHostingView(rootView:
                                ClipboardDetailView(text: item)
                            )
                            detailWindow.makeKeyAndOrderFront(nil)
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

struct ClipboardDetailView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}
