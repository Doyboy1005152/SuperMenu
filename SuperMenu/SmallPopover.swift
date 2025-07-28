import SwiftUI
import AppKit

class SmallPopover {
    public static func showCenteredMessage(_ message: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient]

        let screenFrame = NSScreen.main?.frame ?? .zero
        let windowSize = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: (screenFrame.width - windowSize.width) / 2,
            y: (screenFrame.height - windowSize.height) / 2
        ))

        let hostingView = NSHostingView(rootView:
            Text(message)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.25))
                .cornerRadius(10)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 100)
        window.contentView = hostingView

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }) {
            // Delay 1 second, then fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.5
                    window.animator().alphaValue = 0
                }) {
                    window.orderOut(nil)
                }
            }
        }
    }
}
