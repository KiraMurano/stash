import AppKit
import ApplicationServices

/// What the panel opens next to.
enum CaretAnchor: Equatable {
    /// The text cursor itself.
    case caret(CGRect)
    /// The focused text field, for apps that do not report the caret (Electron apps, terminals).
    case field(CGRect)

    var rect: CGRect {
        switch self {
        case let .caret(rect): return rect
        case let .field(rect): return rect
        }
    }
}

/// Asks the frontmost app, through Accessibility, where its text cursor is. Stash needs that
/// permission anyway to paste, so nothing new is requested here.
@MainActor
enum CaretLocator {
    /// A hung app must not hold up the panel.
    private static let timeout: Float = 0.2

    static func anchor() -> CaretAnchor? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)

        guard
            let focused = attribute(system, kAXFocusedUIElementAttribute),
            CFGetTypeID(focused) == AXUIElementGetTypeID()
        else {
            return nil
        }

        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, timeout)

        if let range = attribute(element, kAXSelectedTextRangeAttribute) {
            var bounds: CFTypeRef?
            let status = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                range,
                &bounds
            )
            // Electron apps answer with an empty rectangle; take it only when it has a height.
            if status == .success, let rect = screenRect(bounds), rect.height > 0, isOnScreen(rect) {
                return .caret(rect)
            }
        }

        if let rect = fieldRect(of: element), isOnScreen(rect) {
            return .field(rect)
        }

        return nil
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func fieldRect(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue = attribute(element, kAXPositionAttribute),
            let sizeValue = attribute(element, kAXSizeAttribute),
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size),
            size.height > 0
        else {
            return nil
        }

        return flipped(CGRect(origin: position, size: size))
    }

    private static func screenRect(_ value: CFTypeRef?) -> CGRect? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
        return flipped(rect)
    }

    /// Accessibility counts from the top of the primary screen, AppKit from its bottom.
    private static func flipped(_ rect: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return rect }
        return CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func isOnScreen(_ rect: CGRect) -> Bool {
        NSScreen.screens.contains { $0.frame.intersects(rect) }
    }
}
