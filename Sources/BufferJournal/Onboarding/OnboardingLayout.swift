import AppKit

enum OnboardingLayout {
    /// The largest scene canvas. Each scene has its own size, fitted to what it shows; this one
    /// stands in for a scene that is not built yet.
    static let sceneSize = CGSize(width: 480, height: 240)

    /// The scene grows or shrinks until it meets the width or the height of the room, keeping
    /// its proportions.
    static func sceneScale(_ scene: CGSize, in area: CGSize) -> CGFloat {
        guard scene.width > 0, scene.height > 0, area.width > 0, area.height > 0 else { return 0 }
        return min(area.width / scene.width, area.height / scene.height)
    }

    /// The card hugs its scene at the scale the scene gets: it takes the whole width or the whole
    /// height of the room, and no more than the scene needs of the other.
    static func cardSize(for scene: CGSize, in area: CGSize) -> CGSize {
        let scale = sceneScale(scene, in: area)
        return CGSize(width: scene.width * scale, height: scene.height * scale)
    }

    /// The journal header's lockup: a 32 pt icon, a 2 pt gap and "Stash" at 28 pt heavy.
    struct Lockup: Equatable {
        var icon: CGFloat
        var gap: CGFloat
        var fontSize: CGFloat
    }

    static let headerLockup = Lockup(icon: 32, gap: 2, fontSize: 28)

    /// The header lockup scaled up to 80 % of the area's width or height, whichever binds first.
    /// `wordWidthAt28` is the width of "Stash" at 28 pt heavy.
    static func heroLockup(in area: CGSize, wordWidthAt28: CGFloat) -> Lockup {
        let natural = headerLockup
        let width = natural.icon + natural.gap + wordWidthAt28
        guard width > 0, area.width > 0, area.height > 0 else { return Lockup(icon: 0, gap: 0, fontSize: 0) }
        let k = min(area.width * 0.8 / width, area.height * 0.8 / natural.icon)
        return Lockup(icon: natural.icon * k, gap: natural.gap * k, fontSize: natural.fontSize * k)
    }

    /// Spare width for the title, and the share of the panel height it may take.
    static let titleSlack: CGFloat = 1.02
    static let titleHeightShare: CGFloat = 0.085

    /// The first slide's title: as wide as its row allows, capped at 10 % of the panel height.
    /// `widthAt100` is the title's width at 100 pt.
    static func titleFontSize(widthAt100: CGFloat, rowWidth: CGFloat, panelHeight: CGFloat) -> CGFloat {
        let cap = (panelHeight * titleHeightShare).rounded()
        guard widthAt100 > 0 else { return max(cap, 1) }
        let byWidth = floor(100 * rowWidth / (widthAt100 * titleSlack))
        return max(1, min(byWidth, cap))
    }
}

/// Widths of text in the heavy system font: the "Stash" wordmark and the first slide's title.
enum HeavyTextMetrics {
    static func width(_ text: String, size: CGFloat, tracking: CGFloat = 0) -> CGFloat {
        let font = NSFont.systemFont(ofSize: size, weight: .heavy)
        return ceil(NSAttributedString(string: text, attributes: [.font: font, .kern: tracking]).size().width)
    }

    static func capHeight(size: CGFloat) -> CGFloat {
        NSFont.systemFont(ofSize: size, weight: .heavy).capHeight
    }
}
