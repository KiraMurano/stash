import AppKit
import SwiftUI

// Stand-ins for SwiftUI that arrived with macOS 13. Stash runs on macOS 12 here, so each one
// keeps the 13+ behaviour where it can and falls back to something close where it cannot.

/// `AnyShape` from macOS 13.
struct AnyShapeCompat: Shape {
    private let makePath: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        makePath = { shape.path(in: $0) }
    }

    func path(in rect: CGRect) -> Path {
        makePath(rect)
    }
}

/// `ImageRenderer` from macOS 13, on any macOS: the view is hosted off screen and drawn into a
/// bitmap at the given scale. Main thread only, like the real one.
enum ViewImageRenderer {
    static func nsImage<Content: View>(of content: Content, size: CGSize, scale: CGFloat) -> NSImage? {
        dispatchPrecondition(condition: .onQueue(.main))
        let host = NSHostingView(rootView: content)
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}

extension View {
    /// `scrollContentBackground(.hidden)` on macOS 13; on 12 the text view is told directly.
    @ViewBuilder
    func hiddenScrollContentBackground() -> some View {
        if #available(macOS 13.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// On macOS 12 `TextEditor` paints an opaque background that nothing in SwiftUI can switch off,
// so the text view underneath is made transparent as it is laid out.
extension NSTextView {
    open override var frame: CGRect {
        didSet {
            guard #unavailable(macOS 13.0) else { return }
            drawsBackground = false
            backgroundColor = .clear
        }
    }
}
