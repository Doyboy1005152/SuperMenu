import SwiftUI

struct HTTPView: View {
    @State private var url = ""
    @State private var method = "GET"
    @State private var bodyText = ""
    @State private var responseText = ""
    @State private var isLoading = false
    @State private var selectedScheme = "https"
    @AppStorage("allowInsecureHTTP") private var allowInsecure = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live HTTP Request Tester")
                .font(.headline)

            Picker("Scheme", selection: $selectedScheme) {
                Text("https").tag("https")
                Text("http").tag("http")
                Text("none").tag("none")
            }
            .pickerStyle(SegmentedPickerStyle())

            Toggle("Allow insecure connections", isOn: $allowInsecure)

            TextField("URL", text: $url)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    sendRequest()
                }
                .onChange(of: url) { _, newValue in
                    if newValue.lowercased().hasPrefix("http://") || newValue.lowercased().hasPrefix("https://") {
                        selectedScheme = "none"
                    }
                }

            Picker("Method", selection: $method) {
                Text("GET").tag("GET")
                Text("POST").tag("POST")
                Text("PUT").tag("PUT")
                Text("DELETE").tag("DELETE")
            }
            .pickerStyle(SegmentedPickerStyle())

            if method != "GET" {
                TextEditor(text: $bodyText)
                    .frame(height: 100)
                    .border(Color.gray, width: 1)
            }

            Button(action: sendRequest) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Send Request")
                }
            }
            .disabled(url.isEmpty || isLoading)

            Text("Response:")
                .font(.subheadline)
                .padding(.top, 4)

            ScrollView {
                Text(responseText.isEmpty ? "(No response yet)" : responseText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            Button("Copy Response") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(responseText, forType: .string)
            }
            .disabled(responseText.isEmpty)
            .padding(.top, 8)
        }
        .padding()
    }
    
    func sendRequest() {
        if url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") {
            selectedScheme = "none"
        }
        var fullURL = url
        if selectedScheme != "none" && !url.starts(with: "\(selectedScheme)://") {
            fullURL = "\(selectedScheme)://\(url)"
        }
        guard let requestURL = URL(string: fullURL) else {
            responseText = "Invalid URL."
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        if method != "GET" {
            request.httpBody = bodyText.data(using: .utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let session: URLSession
        if allowInsecure {
            let config = URLSessionConfiguration.default
            let delegate = InsecureSessionDelegate()
            session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        } else {
            session = URLSession.shared
        }

        isLoading = true
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    responseText = "Error: \(error.localizedDescription)"
                } else if let data = data, let output = String(data: data, encoding: .utf8) {
                    responseText = output
                } else {
                    responseText = "No data received."
                }
            }
        }.resume()
    }
}

class InsecureSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}
