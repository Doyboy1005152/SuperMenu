import SwiftUI
import Foundation

struct FeedbackView: View {
    @State var feedback: String = ""
    @State var rating: Int = 0
    @Binding var isPresented: Bool
    var body: some View {
        VStack {
            Text("What do you think of SuperMenu?")
                .font(.system(size: 36, weight: .bold))
                .padding()
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: rating >= index ? "star.fill" : "star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(rating >= index ? .accentColor : .gray)
                        .onTapGesture {
                            rating = index
                        }
                }
            }
            .padding()
            TextField("", text: $feedback)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(6)
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Submit") {
                    Task {
                        await submitFeedback()
                        isPresented = false
                        SmallPopover.showCenteredMessage("Thank you for your feedback!", systemImage: "hand.thumbsup", secondSystemImage: "hand.thumbsup.fill", duration: 3.0)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    func submitFeedback() async {
        //Still setting up server
    }
}
