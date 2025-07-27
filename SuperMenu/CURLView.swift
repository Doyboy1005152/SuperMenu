import Foundation
import SwiftUI

struct CURLView: View {
    @State var cURLText: String = ""
    @State var outputText: String = ""
    var body: some View {
        VStack {
            TextField("Enter cURL command", text: $cURLText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onSubmit {
                    runCURL()
                }

            Button("Run cURL") {
                runCURL()
            }
            .padding()

            ScrollView {
                Text(outputText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    private func runCURL() {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", cURLText]

        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.outputText = output
            }
        }
    }
}
