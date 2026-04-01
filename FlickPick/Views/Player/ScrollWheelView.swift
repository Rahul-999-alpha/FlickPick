import SwiftUI
import AppKit

/// Captures scroll wheel events and converts to volume changes.
struct ScrollWheelView: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollWheelNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        // deltaY > 0 = scroll up = volume up
        let delta = event.scrollingDeltaY
        if abs(delta) > 0.1 {
            onScroll?(delta)
        }
    }
}
