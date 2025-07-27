import Foundation

class Ports {
    public func listAllOpenPorts() -> [Ports.Port] {
        var result: [Ports.Port] = []

        let process = Process()
        process.launchPath = "/usr/sbin/lsof"
        process.arguments = ["-i", "-nP"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return result
        }

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            // Skip header
            if line.hasPrefix("COMMAND") || line.isEmpty {
                continue
            }

            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count > 8 else { continue }

            let nameInfo = components[8]

            if let portRange = nameInfo.range(of: ":(\\d+)", options: .regularExpression) {
                let portString = String(nameInfo[portRange]).replacingOccurrences(of: ":", with: "")
                if let port = Int(portString) {
                    let status = nameInfo.contains("LISTEN") ? "LISTENING" : "CONNECTED"
                    result.append(.init(status: status, port: port))
                }
            }
        }

        return result
    }
    
    public func getPortState(port: Int) -> Ports.Port? {
        let process = Process()
        process.launchPath = "/usr/sbin/lsof"
        process.arguments = ["-i:\(port)", "-nP"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("LISTEN") {
                return .init(status: "LISTENING", port: port)
            } else if !line.hasPrefix("COMMAND") && !line.isEmpty {
                return .init(status: "CONNECTED", port: port)
            }
        }

        return nil
    }
    
    public func killProcessOnPort(_ port: Int) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = ["lsof", "-ti:\(port)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8),
              let pidString = output.components(separatedBy: .newlines).first,
              let pid = Int(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        let killProcess = Process()
        killProcess.launchPath = "/bin/kill"
        killProcess.arguments = ["-9", "\(pid)"]
        killProcess.launch()
        killProcess.waitUntilExit()

        return killProcess.terminationStatus == 0
    }

    public struct Port: Identifiable {
        let id = UUID()
        let status: String
        let port: Int
    }
}
