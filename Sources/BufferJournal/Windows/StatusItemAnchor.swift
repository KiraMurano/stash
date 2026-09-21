import AppKit

/// Where a window hanging from the status item goes.
///
/// Not under the middle of the icon: the status item sits near the right edge of the menu bar,
/// and a window centred on it is pushed left by the edge of the screen almost every time — the
/// concept measured 101 pt of drift even with three other icons to the right of ours. The right
/// edge of the window is tied to the right edge of the icon instead, so nothing ever drifts
/// (`.concepts/2026-09-21-separate-windows-round1.html`, variant 3.2).
enum StatusItemAnchor {
    /// How far the window's right edge sits past the icon's.
    static let rightInset: CGFloat = 6
    /// Between the menu bar and the top of the window.
    static let topGap: CGFloat = 8
    /// The least room left between the window and the sides of the screen.
    static let screenMargin: CGFloat = 12
    /// The least room left under a window that grows with its content.
    static let bottomMargin: CGFloat = 16

    /// `itemFrame` is the status item button's frame in screen coordinates, `visibleFrame` the
    /// screen's usable area — it already excludes the menu bar.
    static func origin(itemFrame: NSRect, windowSize: NSSize, visibleFrame: NSRect) -> NSPoint {
        let right = min(itemFrame.maxX + rightInset, visibleFrame.maxX - screenMargin)
        let x = max(right - windowSize.width, visibleFrame.minX + screenMargin)
        let y = visibleFrame.maxY - topGap - windowSize.height
        return NSPoint(x: x, y: y)
    }
}
