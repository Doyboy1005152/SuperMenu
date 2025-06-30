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
