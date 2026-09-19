import AppKit
import SwiftUI

struct ThemePalette {
    let colorScheme: ColorScheme
    /// Stash Light / Stash Dark: opaque accents and buttons instead of translucent tints.
    var solid = false

    var isDark: Bool {
        colorScheme == .dark
    }

    /// Orange from the app icon (#F46A25).
    static let orange = Color(red: 244 / 255, green: 106 / 255, blue: 37 / 255)

    /// Frosted tint over the glass for the list pane (denser) and the preview pane (lighter).
    var sidebarTint: Color {
        isDark ? Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255).opacity(0.84) : Color.white.opacity(0.82)
    }

    var detailTint: Color {
        isDark ? Color(red: 18 / 255, green: 18 / 255, blue: 20 / 255).opacity(0.42) : Color.white.opacity(0.38)
    }

    /// Orange for text and small marks, tuned per appearance for contrast.
    var accentText: Color {
        isDark ? Color(red: 1, green: 138 / 255, blue: 76 / 255) : Color(red: 217 / 255, green: 86 / 255, blue: 26 / 255)
    }

    /// Soft orange behind the selected row.
    var accentSoft: Color {
        Self.orange.opacity(isDark ? 0.22 : 0.13)
    }

    /// One tight shadow for small raised things in rows: thumbnails and the quick-paste button.
    static let controlShadowRadius: CGFloat = 1

    var controlShadow: Color {
        shadow(0.28)
    }

    /// Dim layer behind confirmation dialogs.
    var dialogBackdrop: Color {
        Color.black.opacity(isDark ? 0.32 : 0.16)
    }

    /// Translucent orange thumb of the type filter.
    var segmentThumb: Color {
        solid ? Self.orange : Self.orange.opacity(isDark ? 0.28 : 0.18)
    }

    /// Fill and text for orange accents that carry a label: selected row, active filter, badges.
    var accentFill: Color {
        solid ? Self.orange : accentSoft
    }

    var onAccent: Color {
        solid ? .white : accentText
    }

    var onAccentSecondary: Color {
        solid ? Color.white.opacity(0.78) : textTertiary
    }

    /// Opaque grey for buttons in the Stash themes; `level` 0 rest, 1 hover, 2 pressed.
    func solidControl(_ level: Double) -> Color {
        isDark ? Color(white: 0.30 + 0.05 * level) : Color(white: 0.93 - 0.04 * level)
    }

    static let solidDestructive = Color(red: 0.86, green: 0.21, blue: 0.19)

    /// Opaque hover/press shade; `Color.mix` needs macOS 15.
    static func darken(_ color: Color, by fraction: Double) -> Color {
        guard fraction > 0, let blended = NSColor(color).blended(withFraction: fraction, of: .black) else { return color }
        return Color(nsColor: blended)
    }

    var windowBackground: Color {
        isDark ? Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255) : Color(red: 0.965, green: 0.965, blue: 0.970)
    }

    var windowTint: Color {
        isDark
            ? Color(red: 34 / 255, green: 34 / 255, blue: 36 / 255).opacity(0.78)
            : Color.white.opacity(0.32)
    }

    var headerBackground: Color {
        isDark ? Color.black.opacity(0.12) : Color.white.opacity(0.18)
    }

    var cardBackground: Color {
        isDark ? Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255) : Color.white
    }

    var cardGlassFill: Color {
        isDark ? .clear : Color.white.opacity(0.70)
    }

    var draggedCardBackground: Color {
        isDark ? Color(red: 0.18, green: 0.18, blue: 0.19) : .white
    }

    var cardHoverBackground: Color {
        isDark ? Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255) : Color(white: 0.965)
    }

    var modalBackground: Color {
        isDark ? Color(red: 0.145, green: 0.145, blue: 0.150) : Color.white
    }

    var backdropTint: Color {
        isDark ? Color.black.opacity(0.10) : Color.white.opacity(0.08)
    }

    var controlHoverBackground: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.055)
    }

    var iconGlassTint: Color {
        isDark ? Color.white.opacity(0.055) : Color.white.opacity(0.38)
    }

    var iconGlassBorder: Color {
        isDark ? Color.white.opacity(0.14) : Color.white.opacity(0.48)
    }

    var placeholderBackground: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
    }

    var textPrimary: Color {
        isDark ? Color.white.opacity(0.90) : Color.black.opacity(0.86)
    }

    var textSecondary: Color {
        isDark ? Color.white.opacity(0.58) : Color.black.opacity(0.58)
    }

    var textTertiary: Color {
        isDark ? Color.white.opacity(0.38) : Color.black.opacity(0.38)
    }

    var border: Color {
        isDark ? Color.white.opacity(0.11) : Color.black.opacity(0.10)
    }

    var borderSelected: Color {
        isDark ? Color.white.opacity(0.32) : Color.black.opacity(0.24)
    }

    var separator: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    var expandFadeColor: Color {
        isDark ? windowTint : cardGlassFill.opacity(0.96)
    }

    func iconOpacity(_ opacity: Double) -> Color {
        isDark ? Color.white.opacity(opacity) : Color.black.opacity(opacity)
    }

    func shadow(_ opacity: Double) -> Color {
        Color.black.opacity(isDark ? opacity * 1.45 : opacity)
    }
}
