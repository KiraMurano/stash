import AppKit

/// Where the panel goes when it opens next to the text cursor: under the caret, or above it when
/// there is no room below. Pure maths, in screen coordinates with the origin at the bottom left.
enum PanelPlacement {
    /// Space between the caret and the panel.
    static let gap: CGFloat = 16
    /// Margin kept from the edges of the screen, as when a saved position is restored.
    static let margin: CGFloat = 12

    /// Returns nil when the panel fits neither below nor above the anchor: the caller then falls
    /// back to the panel's saved place. `bottomInset` is the transparent strip under the panel
    /// (the resize grip lives there), so the gap looks the same above the caret and below it.
    static func origin(
        anchor: CGRect,
        panelSize: NSSize,
        visibleFrame: NSRect,
        gap: CGFloat = gap,
        bottomInset: CGFloat = 0
    ) -> NSPoint? {
        let below = anchor.minY - gap - panelSize.height
        let above = anchor.maxY + gap - bottomInset

        let y: CGFloat
        if below >= visibleFrame.minY {
            y = below
        } else if above + panelSize.height <= visibleFrame.maxY {
            y = above
        } else {
            return nil
        }

        // Left edge follows the caret, then the panel is pushed back onto the screen.
        let leftmost = visibleFrame.minX + margin
        let rightmost = max(leftmost, visibleFrame.maxX - panelSize.width - margin)
        return NSPoint(x: min(max(anchor.minX, leftmost), rightmost), y: y)
    }
}
