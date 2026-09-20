import AppKit

/// The orange dot over the status item while an update waits to be looked at.
///
/// The status icon is a template image: macOS paints it black or white to match the menu bar, and
/// an orange dot composited into it would lose that. So the dot is a layer of its own over the
/// untouched glyph.
@MainActor
final class StatusItemBadge {
    static let diameter: CGFloat = 5
    /// How far the dot hangs past the glyph's top right corner (concept round 2, variant 2.1.2).
    private static let overhang: CGFloat = 2

    /// The image sits in the middle of the button, whatever width the button ends up with.
    static func glyphRect(in bounds: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: ((bounds.width - imageSize.width) / 2).rounded(),
            y: ((bounds.height - imageSize.height) / 2).rounded(),
            width: imageSize.width,
            height: imageSize.height
        )
    }

    /// Half on the corner: 3×3 over the glyph, 2 pt out of it on each side.
    static func dotRect(glyph: CGRect) -> CGRect {
        CGRect(
            x: glyph.maxX + overhang - diameter,
            y: glyph.maxY + overhang - diameter,
            width: diameter,
            height: diameter
        )
    }

    /// Fills the button and keeps the dot on the glyph's corner through every relayout.
    private final class Container: NSView {
        let dot = NSView()
        var imageSize = CGSize(width: 14, height: 18)

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            dot.wantsLayer = true
            dot.layer?.backgroundColor = NSColor(
                red: 244 / 255, green: 106 / 255, blue: 37 / 255, alpha: 1
            ).cgColor
            dot.layer?.cornerRadius = StatusItemBadge.diameter / 2
            addSubview(dot)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("not used") }

        override func layout() {
            super.layout()
            dot.frame = StatusItemBadge.dotRect(glyph: StatusItemBadge.glyphRect(in: bounds, imageSize: imageSize))
        }

        // The dot is decoration: every click goes to the button under it.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private let container = Container()

    init(button: NSStatusBarButton) {
        container.frame = button.bounds
        container.autoresizingMask = [.width, .height]
        container.imageSize = button.image?.size ?? CGSize(width: 14, height: 18)
        container.isHidden = true
        button.addSubview(container)
    }

    var isVisible: Bool {
        get { !container.isHidden }
        set {
            container.isHidden = !newValue
            container.needsLayout = true
        }
    }
}
