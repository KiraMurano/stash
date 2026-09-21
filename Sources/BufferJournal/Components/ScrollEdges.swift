import AppKit
import SwiftUI

// Scrolling, shared by the journal's preview pane and the update window: where the content
// stands right now, the shadows that mark an edge with more behind it, and a scroller that
// follows the chosen theme rather than the system one.

/// Reports whether the enclosing scroll view has scrolled away from the top. SwiftUI geometry
/// preferences inside a macOS ScrollView do not update while scrolling, so watch the clip view.
/// Soft shadow cast by a header (`.top`, falls downward) or footer (`.bottom`, rises upward)
/// over content scrolling beneath it.
struct EdgeShadow: View {
    static let height: CGFloat = 20

    let palette: ThemePalette
    let edge: VerticalEdge

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: palette.shadow(0.08), location: 0),
                .init(color: palette.shadow(0.03), location: 0.45),
                .init(color: palette.shadow(0), location: 1)
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: Self.height)
        .allowsHitTesting(false)
    }
}

struct ScrollEdges: Equatable {
    /// Content is scrolled away from the top.
    var isScrolled = false
    /// More content lies below the visible area.
    var hasMoreBelow = false
}

struct ScrollOffsetObserver: NSViewRepresentable {
    let onChange: (ScrollEdges) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onChange = onChange
    }

    @MainActor
    final class Coordinator {
        var onChange: (ScrollEdges) -> Void
        private weak var scrollView: NSScrollView?
        private var observers: [NSObjectProtocol] = []
        private var lastValue = ScrollEdges()

        init(onChange: @escaping (ScrollEdges) -> Void) {
            self.onChange = onChange
        }

        func attach(from view: NSView, attempt: Int = 0) {
            guard scrollView == nil else { return }
            guard let scrollView = Self.findScrollView(near: view) else {
                // Frames are still zero right after creation; try again once SwiftUI has laid out.
                if attempt < 20 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak view] in
                        guard let view else { return }
                        self?.attach(from: view, attempt: attempt + 1)
                    }
                }
                return
            }
            self.scrollView = scrollView
            let clipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true
            clipView.postsFrameChangedNotifications = true
            scrollView.documentView?.postsFrameChangedNotifications = true
            // Scrolling moves the clip view's bounds; resizing the panel or the content changes frames.
            for (name, object) in [
                (NSView.boundsDidChangeNotification, clipView as NSView),
                (NSView.frameDidChangeNotification, clipView as NSView),
                (NSView.frameDidChangeNotification, scrollView.documentView),
            ] {
                guard let object else { continue }
                observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.report()
                    }
                })
            }
            report()
        }

        private func report() {
            guard let scrollView else { return }
            let clip = scrollView.contentView.bounds
            let offset = clip.origin.y + scrollView.contentInsets.top
            let contentHeight = scrollView.documentView?.frame.height ?? 0
            let edges = ScrollEdges(
                isScrolled: offset > 1,
                hasMoreBelow: clip.maxY < contentHeight - 1
            )
            guard edges != lastValue else { return }
            lastValue = edges
            onChange(edges)
        }

        /// The observer is the list's background, so the list's scroll view is the one that
        /// covers the same area of the window. Walk up and search each ancestor's subtree for it.
        private static func findScrollView(near view: NSView) -> NSScrollView? {
            guard view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else { return nil }
            let target = view.convert(view.bounds, to: nil)

            var ancestor = view.superview
            while let current = ancestor {
                if let match = scrollView(in: current, matching: target) {
                    return match
                }
                ancestor = current.superview
            }
            return nil
        }

        private static func scrollView(in root: NSView, matching target: NSRect) -> NSScrollView? {
            for subview in root.subviews {
                if let scrollView = subview as? NSScrollView {
                    let frame = scrollView.convert(scrollView.bounds, to: nil)
                    let overlap = frame.intersection(target)
                    if !overlap.isNull, overlap.width * overlap.height >= 0.8 * target.width * target.height {
                        return scrollView
                    }
                    continue
                }
                if let match = scrollView(in: subview, matching: target) {
                    return match
                }
            }
            return nil
        }
    }
}

struct ScrollBarAppearanceSetter: NSViewRepresentable {
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.postsFrameChangedNotifications = false
        DispatchQueue.main.async {
            applyAppearance(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyAppearance(from: nsView)
        }
    }

    private func applyAppearance(from view: NSView) {
        guard let scrollView = scrollView(containing: view) else {
            return
        }

        let scrollerAppearanceName: NSAppearance.Name = colorScheme == .dark ? .darkAqua : .aqua
        let scrollerAppearance = NSAppearance(named: scrollerAppearanceName)
        let knobStyle: NSScroller.KnobStyle = colorScheme == .dark ? .light : .dark
        // Thin overlay scrollers that only show while scrolling, even when the system setting
        // (or an attached mouse) asks for always-visible legacy scrollers.
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.verticalScroller?.appearance = scrollerAppearance
        scrollView.horizontalScroller?.appearance = scrollerAppearance
        scrollView.verticalScroller?.knobStyle = knobStyle
        scrollView.horizontalScroller?.knobStyle = knobStyle
    }

    private func scrollView(containing view: NSView) -> NSScrollView? {
        if let scrollView = view.enclosingScrollView {
            return scrollView
        }

        var ancestor = view.superview
        while let current = ancestor {
            if let scrollView = firstScrollView(in: current) {
                return scrollView
            }
            ancestor = current.superview
        }

        if let contentView = view.window?.contentView {
            return firstScrollView(in: contentView)
        }

        return nil
    }

    private func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }

        for subview in view.subviews {
            if let scrollView = firstScrollView(in: subview) {
                return scrollView
            }
        }

        return nil
    }
}
