import SwiftUI

struct JWTDecoderView: View {
    @State private var jwtInput: String = ""
    @State private var decodedHeader: String = ""
    @State private var decodedPayload: String = ""
    @State private var signature: String = ""
    @State private var showError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("JWT Decoder")
                .font(.title)
                .bold()

            TextEditor(text: $jwtInput)
                .border(Color.gray)
                .frame(height: 100)
                .onChange(of: jwtInput) { decodeJWT() }

            VStack(alignment: .leading, spacing: 12) {
                if showError {
                    Text("Invalid JWT or JSON").foregroundColor(.red)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Header")
                            .font(.headline)
                        ScrollView(.horizontal) {
                            Text(decodedHeader)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray, lineWidth: 2)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Payload")
                            .font(.headline)
                        ScrollView(.horizontal) {
                            Text(decodedPayload)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray, lineWidth: 2)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signature")
                            .font(.headline)
                        ScrollView(.horizontal) {
                            Text(signature)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray, lineWidth: 2)
                    )
                }
            }
            .padding(.top)

            Spacer()
        }
        .padding()
    }

    func decodeJWT() {
        let parts = jwtInput.components(separatedBy: ".")
        guard parts.count == 3,
              let headerData = Data(base64Encoded: base64urlToBase64(parts[0])),
              let payloadData = Data(base64Encoded: base64urlToBase64(parts[1])),
              let headerString = String(data: headerData, encoding: .utf8),
              let payloadString = String(data: payloadData, encoding: .utf8) else {
            showError = true
            return
        }

        decodedHeader = headerString
        decodedPayload = payloadString
        signature = parts[2]
        showError = false
    }

    func base64urlToBase64(_ base64url: String) -> String {
        var base64 = base64url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        return base64
    }
}
