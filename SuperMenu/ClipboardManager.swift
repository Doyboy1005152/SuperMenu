import AppKit
import Carbon
import Combine
import ServiceManagement
import SwiftUI
internal import UniformTypeIdentifiers

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var isMonitoring: Bool = true {
        didSet {
            if isMonitoring { 
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    @Published var history: [String] = []
    private var changeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?

    private init() {
        if isMonitoring {
            startMonitoring()
        }
    }

    private func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        if pb.changeCount != changeCount {
            changeCount = pb.changeCount
            if let copiedString = pb.string(forType: .string), !copiedString.isEmpty {
                if history.first != copiedString {
                    history.insert(copiedString, at: 0)
                    if history.count > 50 {
                        history.removeLast()
                    }
                }
            }
        }
    }

    func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
