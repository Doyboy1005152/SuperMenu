import SwiftUI

struct ChatbotView: View {
    @State var input: String = ""
    @State var output: String = "Type a message to get started..."

    func chat() async {
        do {
            output = try await input.ask(with: "")
        } catch {
            output = "Sorry, an error occurred: \(error.localizedDescription)"
        }
    }

    var body: some View {
        VStack {
            Text(output)
                .padding()
            TextField("Ask me anything...", text: $input)
                .padding()
                .onSubmit {
                    Task {
                        await chat()
                    }
                }
        }
        .padding()
    }
}
