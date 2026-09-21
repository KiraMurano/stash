import AppKit
import QuartzCore
import SwiftUI

/// A window of Stash that is not the journal: the update screen, About and the tour.
///
/// Borderless and never key, like the journal panel — whatever the person types keeps going to
/// the app underneath. Unlike the journal it is placed by a rule rather than by the person: it
/// hangs from the status item or stands in the middle of the screen, so it neither moves nor
/// remembers where it was.
@MainActor
final class AccessoryWindow<Content: View> {
    enum Placement {
        /// Right edge just past the status item's, top edge under the menu bar. The closure is
        /// asked every time the window is shown: the item moves as other menu bar icons come and go.
        case statusItem(() -> NSRect?)
        /// The middle of the screen, a touch above centre, like the journal panel's own fallback.
        case center
    }

    enum Sizing {
        case fixed(NSSize)
        /// Fixed width; the height is whatever the content asks for, capped by the screen.
        case fitsContent(width: CGFloat)
    }

    /// The tallest a window that grows with its content may be.
    static func heightCap(visibleFrame: NSRect) -> CGFloat {
        max(120, visibleFrame.height - StatusItemAnchor.topGap - StatusItemAnchor.bottomMargin)
    }

    private let placement: Placement
    private let sizing: Sizing
    private let rootView: Content
    private let closesOnOutsideClick: () -> Bool
    private let panel: NSPanel
    private let hostingView: FirstMouseHostingView<Content>
    private var outsideClickMonitor: Any?

    var isVisible: Bool { panel.isVisible }

    /// What the window measures right now. Borderless, so this is its content size too.
    var contentSize: NSSize { panel.frame.size }

    init(
        placement: Placement,
        sizing: Sizing,
        cornerRadius: CGFloat,
        closesOnOutsideClick: @escaping () -> Bool = { false },
        rootView: Content
    ) {
        self.placement = placement
        self.sizing = sizing
        self.rootView = rootView
        self.closesOnOutsideClick = closesOnOutsideClick

        hostingView = FirstMouseHostingView(rootView: rootView)

        let initialSize: NSSize
        switch sizing {
        case .fixed(let size):
            initialSize = size
        case .fitsContent(let width):
            // Replaced by the content's own height the moment it reports one.
            initialSize = NSSize(width: width, height: 200)
        }

        panel = NeverKeyPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // The hosting view goes inside a plain container rather than straight into the window.
        // As the window's own content view it hands the window its constraints, and the window
        // then snaps back to SwiftUI's ideal height — one line per paragraph — a moment after
        // the real height is set. Held by an autoresizing mask, it has no say in the size.
        let container = NSView(frame: NSRect(origin: .zero, size: initialSize))
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)
        panel.contentView = container
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.animationBehavior = .none
        // Stash stays inactive while these windows are open; without this their tooltips never show.
        panel.allowsToolTipsWhenApplicationIsInactive = true
        panel.canHide = false

        if case .fitsContent(let width) = sizing {
            // No `sizingOptions`: an intrinsic size would have Auto Layout resize the window to
            // SwiftUI's ideal height a moment after the line below sets the real one, and the
            // ideal height of a paragraph is one line. The window's size is set here and nowhere
            // else; the view simply fills it.
            fitToContent()
        }
    }

    /// Ask the content how tall it wants to be and give it that, up to the screen's height.
    /// Call it whenever what the window shows has changed.
    func fitToContent() {
        resizeToFitContent()
    }

    /// The window takes the height its content asks for, up to the screen's. It grows downward:
    /// the top edge belongs to the menu bar, so the origin is reapplied after every change.
    ///
    /// The width is *proposed*, not constrained: a constraint leaves SwiftUI measuring its ideal
    /// size, and a line of text is ideally one line however long it is. Measured that way a list
    /// that wraps came out barely half its real height.
    private func resizeToFitContent() {
        guard case .fitsContent(let width) = sizing else { return }
        let cap = currentCap

        let measured = NSHostingController(rootView: rootView)
            .sizeThatFits(in: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            .height
        guard measured > 0, measured.isFinite else { return }

        let height = min(measured, cap)
        if abs(height - panel.frame.height) > 0.5 {
            panel.setContentSize(NSSize(width: width, height: height))
        }
        applyPlacement()
    }

    private var currentCap: CGFloat {
        guard let screen = currentScreen else { return 10_000 }
        return Self.heightCap(visibleFrame: screen.visibleFrame)
    }

    func show() {
        resizeToFitContent()
        applyPlacement()
        panel.alphaValue = 0
        // Never key: typing stays with the app under the window.
        panel.orderFrontRegardless()
        watchOutsideClicks()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = PanelPresentation.appearDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        stopWatchingOutsideClicks()
        guard panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = PanelPresentation.disappearDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
                panel?.alphaValue = 1
            }
        }
    }

    private var currentScreen: NSScreen? {
        if case .statusItem(let itemFrame) = placement, let frame = itemFrame() {
            return NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
        }
        return NSScreen.main
    }

    private func applyPlacement() {
        switch placement {
        case .statusItem(let itemFrame):
            guard let frame = itemFrame(), let screen = currentScreen else { return }
            panel.setFrameOrigin(StatusItemAnchor.origin(
                itemFrame: frame,
                windowSize: panel.frame.size,
                visibleFrame: screen.visibleFrame
            ))
        case .center:
            guard let screen = NSScreen.main else {
                panel.center()
                return
            }
            let visible = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2 + 40
            ))
        }
    }

    /// A global monitor never sees clicks on Stash itself, so whatever it reports happened
    /// somewhere else. The predicate is asked at the moment of the click, not when the monitor
    /// is installed: the update window stays put while it is downloading.
    private func watchOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.closesOnOutsideClick() else { return }
                self.close()
            }
        }
    }

    private func stopWatchingOutsideClicks() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }
}

/// Never key: the keyboard stays with the app the person is typing in, even after a click.
private final class NeverKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
