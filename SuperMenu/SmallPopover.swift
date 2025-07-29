import SwiftUI

class SmallPopover {
    public static func showCenteredMessage(_ message: String, systemImage: String? = nil, secondSystemImage: String? = nil, duration: TimeInterval = 2.0) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
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

        struct MessageView: View {
            let message: String
            let firstImage: String?
            let secondImage: String?
            let duration: TimeInterval

            @State private var currentImage: String?

            var body: some View {
                HStack {
                    if let currentImage {
                        Image(systemName: currentImage)
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                    Text(message)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
                .onAppear {
                    currentImage = firstImage
                    if let second = secondImage {
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.duration / 2) {
                            withAnimation {
                                currentImage = second
                            }
                        }
                    }
                }
            }
        }

        let hostingView = NSHostingView(rootView:
            MessageView(message: message, firstImage: systemImage, secondImage: secondSystemImage, duration: duration)
        )

        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        window.setContentSize(hostingView.fittingSize)

        let screenFrame = NSScreen.main?.frame ?? .zero
        let windowSize = hostingView.fittingSize
        window.setFrameOrigin(NSPoint(
            x: (screenFrame.width - windowSize.width) / 2,
            y: (screenFrame.height - windowSize.height) / 2
        ))

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }) {
            // Delay duration seconds, then fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
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
