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
    private let closesOnOutsideClick: () -> Bool
    private let panel: NSPanel
    private let hostingView: FirstMouseHostingView<Content>
    private var heightCapConstraint: NSLayoutConstraint?
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
        self.closesOnOutsideClick = closesOnOutsideClick

        hostingView = FirstMouseHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = cornerRadius
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true

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
        panel.contentView = hostingView
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
            // `sizingOptions` makes the view report the height SwiftUI wants; it does not pass
            // that height to the window, so the window is resized by hand below.
            hostingView.sizingOptions = [.intrinsicContentSize]
            hostingView.widthAnchor.constraint(equalToConstant: width).isActive = true
            // The cap belongs on the view as well as on the window: it is what makes the notes
            // inside compress and their ScrollView start scrolling.
            let cap = hostingView.heightAnchor.constraint(lessThanOrEqualToConstant: 10_000)
            cap.isActive = true
            heightCapConstraint = cap

            // The list grows and shrinks as the screen changes state, and so does the window.
            // Coalesced through the run loop: this fires from inside layout.
            hostingView.onIntrinsicSizeChange = { [weak self] in
                Task { @MainActor in self?.resizeToFitContent() }
            }

            resizeToFitContent()
        }
    }

    /// The window takes the height its content asks for, up to the screen's. It grows downward:
    /// the top edge belongs to the menu bar, so the origin is reapplied after every change.
    private func resizeToFitContent() {
        guard case .fitsContent(let width) = sizing else { return }
        heightCapConstraint?.constant = currentCap
        panel.layoutIfNeeded()

        let height = min(hostingView.fittingSize.height, currentCap)
        guard height > 0 else { return }
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
        if case .fitsContent = sizing {
            resizeToFitContent()
        }
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
    /// Called whenever SwiftUI decides the content wants a different size.
    var onIntrinsicSizeChange: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onIntrinsicSizeChange?()
    }
}
