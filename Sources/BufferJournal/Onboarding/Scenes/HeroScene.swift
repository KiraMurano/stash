import AppKit
import SwiftUI

/// ПРИВЕТ, ЭТО: no card; the slide's title above says "Hello, this is". The Stash icon rises. A text,
/// a photo and a PDF, as journal row tiles, swoop
/// in on arcs, tumbling and trailing, and drop into the icon from above: they pass behind it and
/// are gone. Each hit flashes and squashes the icon; the last hits hardest, shakes the lockup and
/// pushes "Stash" out from behind the icon. The lockup is the journal header's (icon 32 : type
/// 28 : gap 2), scaled up.
struct HeroScene: View {
    static let duration = 2.6

    struct State: Equatable {
        var iconOpacity: Double
        var iconRise: Double
        /// Squash and stretch from the hits, 1 when still.
        var iconScaleX: Double
        var iconScaleY: Double
        /// White flash over the icon at a hit, 0…1.
        var flash: Double
        /// Sideways shake of the lockup after the last hit, in points.
        var shake: Double
        /// 0…1 along each tile's flight; nil before it sets off and after it is in.
        var tiles: [Double?]
        var wordOpacity: Double
        var wordShift: Double
    }

    static let departures = [0.3, 0.48, 0.66]
    static let flight = 0.45
    static let hits = departures.map { $0 + flight }

    private static let iconOpacity = Track(0.0).to(1, at: 0.1, until: 0.45, .easeOut)
    private static let iconRise = Track(24.0).to(0, at: 0.1, until: 0.55, .easeOut)
    private static let wordOpacity = Track(0.0).to(1, at: 1.14, until: 1.32, .easeOut)
    /// Out from behind the icon with a little overshoot.
    private static let wordShift = Track(-56.0).to(6, at: 1.12, until: 1.44, .easeOut).to(0, at: 1.44, until: 1.66, .easeInOut)

    static func state(at time: SceneTime) -> State {
        let t = time.t
        let squash = impact(at: t)
        let last = hits[hits.count - 1]
        return State(
            iconOpacity: iconOpacity.value(at: time),
            iconRise: iconRise.value(at: time),
            iconScaleX: 1 + 0.08 * squash,
            iconScaleY: 1 - 0.12 * squash,
            flash: hits.map { hit in t >= hit && t < hit + 0.2 ? 0.55 * (1 - (t - hit) / 0.2) : 0 }.max() ?? 0,
            shake: t >= last && t < last + 0.3 ? 5 * sin((t - last) * 60) * (1 - (t - last) / 0.3) : 0,
            tiles: departures.map { start in t >= start && t < start + flight ? (t - start) / flight : nil },
            wordOpacity: wordOpacity.value(at: time),
            wordShift: wordShift.value(at: time)
        )
    }

    /// Positive squashes (wider, lower), negative stretches. Each hit squashes, then springs back
    /// past still; the last is 1.6 times as hard.
    private static func impact(at t: Double) -> Double {
        for (index, hit) in hits.enumerated().reversed() {
            let since = t - hit
            guard since >= 0, since < 0.3 else { continue }
            let strength = index == hits.count - 1 ? 1.6 : 1
            if since < 0.12 {
                return strength * sin(.pi * since / 0.12)
            }
            return -0.45 * strength * sin(.pi * (since - 0.12) / 0.18)
        }
        return 0
    }

    let time: SceneTime
    let area: CGSize

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    /// Everything the frame is drawn from, worked out once per body. Split off from `body`
    /// because Swift 5.7 cannot type-check the whole scene as one expression.
    private struct Frame {
        let palette: ThemePalette
        let colors: OnboardingColors
        let lockup: OnboardingLayout.Lockup
        let capHeight: CGFloat
        let left: CGFloat
        let top: CGFloat
        let tile: CGFloat
        let flights: [Flight]
        let clips: [DemoClip]
    }

    private var frame: Frame {
        let lockup = OnboardingLayout.heroLockup(in: area, wordWidthAt28: HeavyTextMetrics.width("Stash", size: 28))
        let wordWidth = HeavyTextMetrics.width("Stash", size: lockup.fontSize)
        let left: CGFloat = (area.width - (lockup.icon + lockup.gap + wordWidth)) / 2
        let top: CGFloat = (area.height - lockup.icon) / 2
        let icon = CGPoint(x: left + lockup.icon / 2, y: top + lockup.icon / 2)
        let clips = [
            DemoClips.text("hero-text", Localized(en: "Address", ru: "Адрес"), l10n, at: 14, 20),
            DemoClips.image("hero-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.file("hero-file", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
        ]
        return Frame(
            palette: ThemePalette.scene(colorScheme),
            colors: OnboardingColors(isDark: colorScheme == .dark),
            lockup: lockup,
            capHeight: HeavyTextMetrics.capHeight(size: lockup.fontSize),
            left: left,
            top: top,
            tile: lockup.icon * 0.66,
            flights: Self.flights(in: area, to: icon),
            clips: clips
        )
    }

    var body: some View {
        let state = Self.state(at: time)
        let frame = self.frame
        ZStack(alignment: .topLeading) {
            tiles(state: state, frame: frame)
            lockupView(state: state, frame: frame)
        }
        // Pinned to the area's corner: the offsets above count from it, flying tiles or not.
        .frame(width: area.width, height: area.height, alignment: .topLeading)
    }

    // Tiles fly under the lockup, so they vanish into the icon instead of covering it.
    private func tiles(state: State, frame: Frame) -> some View {
        ForEach(Array(frame.clips.enumerated()), id: \.element.id) { index, clip in
            if let progress = state.tiles[index] {
                // A trail of fading copies behind each tile reads as speed.
                ForEach(Self.trail, id: \.lag) { ghost in
                    tile(clip, progress: max(progress - ghost.lag, 0), ghost: ghost, flight: frame.flights[index], frame: frame)
                }
            }
        }
    }

    private func tile(_ clip: DemoClip, progress p: Double, ghost: Ghost, flight: Flight, frame: Frame) -> some View {
        let scale: CGFloat = frame.tile / 42 * (1 - 0.62 * SceneCurve.easeIn(p))
        let spin: Double = flight.spin * (1 - SceneCurve.easeOut(p))
        let opacity: Double = ghost.opacity * min(p / 0.1, 1)
        return EntryThumb(entry: clip.entry, thumbnail: clip.thumbnail, fileIcon: clip.fileIcon, palette: frame.palette)
            .scaleEffect(scale)
            .rotationEffect(.degrees(spin))
            .opacity(opacity)
            .position(flight.point(at: SceneCurve.easeIn(p)))
    }

    private func lockupView(state: State, frame: Frame) -> some View {
        let iconImage = Image(nsImage: NSApplication.shared.applicationIconImage)
        let capHeight = frame.capHeight
        return HStack(spacing: frame.lockup.gap) {
            iconImage
                .resizable()
                .interpolation(.high)
                .frame(width: frame.lockup.icon, height: frame.lockup.icon)
                .overlay(Color.white.opacity(state.flash).mask(iconImage.resizable()))
                .scaleEffect(x: state.iconScaleX, y: state.iconScaleY, anchor: .bottom)
                .offset(y: state.iconRise)
                .opacity(state.iconOpacity)
                .zIndex(1)
            Text("Stash")
                .font(.system(size: frame.lockup.fontSize, weight: .heavy))
                .foregroundStyle(frame.colors.wordmark)
                .fixedSize()
                // Centred on the capitals, as in the journal header.
                .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - capHeight / 2 }
                .offset(x: state.wordShift)
                .opacity(state.wordOpacity)
        }
        .frame(height: frame.lockup.icon)
        .offset(x: frame.left + state.shake, y: frame.top)
    }

    private struct Ghost {
        let lag: Double
        let opacity: Double
    }

    /// Four fading copies trail each tile; the tile itself goes last, fully opaque.
    private static let trail = [
        Ghost(lag: 0.2, opacity: 0.08), Ghost(lag: 0.15, opacity: 0.15),
        Ghost(lag: 0.1, opacity: 0.25), Ghost(lag: 0.05, opacity: 0.35), Ghost(lag: 0, opacity: 1),
    ]

    /// A curved path into the icon and the turn a tile makes on it.
    struct Flight {
        let start: CGPoint
        let bend: CGPoint
        let end: CGPoint
        /// Degrees the tile is turned when it sets off; it straightens on the way.
        let spin: Double

        /// Quadratic Bézier from `start` through the pull of `bend` to `end`.
        func point(at p: Double) -> CGPoint {
            let u = 1 - p
            return CGPoint(
                x: u * u * start.x + 2 * u * p * bend.x + p * p * end.x,
                y: u * u * start.y + 2 * u * p * bend.y + p * p * end.y
            )
        }
    }

    /// From the upper left, the upper right and the lower left. Every path bends above the icon, so
    /// each tile comes down into it from the top, like into a pocket.
    static func flights(in area: CGSize, to icon: CGPoint) -> [Flight] {
        let w = area.width
        let h = area.height
        return [
            Flight(start: CGPoint(x: w * 0.1, y: h * 0.22), bend: CGPoint(x: icon.x - w * 0.02, y: -h * 0.15), end: icon, spin: -24),
            Flight(start: CGPoint(x: w * 0.9, y: h * 0.18), bend: CGPoint(x: icon.x + w * 0.2, y: -h * 0.2), end: icon, spin: 28),
            Flight(start: CGPoint(x: w * 0.16, y: h * 0.88), bend: CGPoint(x: icon.x - w * 0.25, y: -h * 0.1), end: icon, spin: -18),
        ]
    }
}
