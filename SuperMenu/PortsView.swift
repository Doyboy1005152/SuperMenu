import SwiftUI

struct PortsView: View {
    let portsObj = Ports()
    @State var inputPort: String = ""
    @State var outputPort: Ports.Port = .init(status: "", port: 0)
    @State var openPorts: [Ports.Port] = []
    @State var killSuccess: Bool = false
    @State var showingPortKillWarning: Bool = false
    @State var showingKillError: Bool = false
    @State var sentFromList: Bool = false
    @AppStorage("showWarningBeforePortKill") private var warnBeforeKill: Bool = true
    @State var showSpecificPort: Bool = false

    var body: some View {
        VStack {
            HStack {
                TextField("Enter port number", text: $inputPort)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 150)
                Button("Check") {
                    checkSpecificPort()
                    showSpecificPort = true
                }
                .buttonStyle(.borderedProminent)
                Button("Kill") {
                    if warnBeforeKill {
                        showingPortKillWarning = true
                    } else {
                        kill()
                    }
                }
            }
            .padding()

            Button("Refresh Ports") {
                getPortList()
            }
            .buttonStyle(.borderedProminent)
            
            if outputPort.port != 0 {
                HStack {
                    Text("Port \(outputPort.port): \(outputPort.status)")
                    Spacer()
                    Button("Kill") {
                        if warnBeforeKill {
                            showingPortKillWarning = true
                        } else {
                            kill()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }

            List(openPorts) { port in
                HStack {
                    Text(String(port.port))
                    Spacer()
                    Text(port.status)
                    Button("Kill") {
                        sentFromList = true
                        if warnBeforeKill {
                            inputPort = String(port.port)
                            showingPortKillWarning = true
                        } else {
                            inputPort = String(port.port)
                            kill()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(5)
            }
        }
        .onAppear {
            getPortList()
        }
        .confirmationDialog("Do you want to kill the port?", isPresented: $showingPortKillWarning, titleVisibility: .visible) {
            Button("Kill Port", role: .confirm) {
                kill()
                showingPortKillWarning = false
            }

            Button("Kill, and Don't Ask Again", role: .confirm) {
                kill()
                showingPortKillWarning = false
                warnBeforeKill = false
            }

            Button("Cancel", role: .cancel) {}
        }
        .alert(isPresented: $showingKillError) {
            Alert(
                title: Text("Error Killing Port \(inputPort)"),
                message: Text("Unable to kill the port. It may be protected by the system, or is not running."),
                dismissButton: .default(Text("Ok"))
            )
        }
    }

    func checkSpecificPort() {
        let port = Int(inputPort) ?? 0
        if let found = portsObj.getPortState(port: port) {
            outputPort = found
        } else {
            outputPort = .init(status: "Not found", port: port)
        }
    }

    func getPortList() {
        openPorts = portsObj.listAllOpenPorts()
    }

    func kill() {
        killSuccess = portsObj.killProcessOnPort(inputPort.toInt() ?? 0)
        showingKillError = !killSuccess
        if sentFromList {
            inputPort = ""
            sentFromList = false
        }
    }
}

#Preview {
    PortsView()
}
