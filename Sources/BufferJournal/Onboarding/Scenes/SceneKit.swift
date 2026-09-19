import AppKit
import SwiftUI

extension ThemePalette {
    /// The Stash look every scene uses, whatever theme the person picked.
    static func scene(_ colorScheme: ColorScheme) -> ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: true)
    }

    /// Opaque copy of the list pane: the window background under the pane's tint.
    var listSurface: some View {
        ZStack {
            windowBackground
            sidebarTint
        }
    }

    /// Opaque copy of the preview pane.
    var detailSurface: some View {
        ZStack {
            windowBackground
            detailTint
        }
    }
}

/// The system arrow with its tip at `state.tip`, squeezed by clicks.
struct SceneCursor: View {
    let state: CursorState

    var body: some View {
        let cursor = NSCursor.arrow
        let size = cursor.image.size
        Image(nsImage: cursor.image)
            .scaleEffect(1 - 0.12 * state.press, anchor: UnitPoint(x: cursor.hotSpot.x / size.width, y: cursor.hotSpot.y / size.height))
            .offset(x: state.tip.x - cursor.hotSpot.x, y: state.tip.y - cursor.hotSpot.y)
            .opacity(state.opacity)
    }
}

/// The orange wave a click sends out.
struct SceneRipple: View {
    let ripple: ClickRipple?

    var body: some View {
        if let ripple {
            Circle()
                .fill(ThemePalette.orange)
                .frame(width: 28, height: 28)
                .scaleEffect(0.5 + 1.4 * ripple.progress)
                .opacity(0.45 * (1 - ripple.progress))
                .position(ripple.center)
        }
    }
}

/// A Mac key: light with a dark lower edge in the light theme, dark grey in the dark one.
/// Pressed, it sinks by 2 pt and the edge disappears.
struct SceneKeycap: View {
    let label: String
    /// A second letter in the lower right corner, as on a Russian keyboard.
    var secondary: String?
    /// A small word under the symbol, like "option".
    var caption: String?
    var size: CGFloat = 64
    let pressed: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: size * 0.19, style: .continuous)
        ZStack {
            shape
                .fill(isDark ? Color.black.opacity(0.6) : Color.black.opacity(0.2))
                .offset(y: pressed ? 0 : 3)
            shape
                .fill(isDark ? Color(white: 0.29) : Color.white)
                .overlay(labels(isDark: isDark))
                .offset(y: pressed ? 2 : 0)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(pressed ? 0.08 : 0.16), radius: pressed ? 3 : 8, y: pressed ? 1 : 5)
        .animation(.easeOut(duration: 0.08), value: pressed)
    }

    private func labels(isDark: Bool) -> some View {
        let ink = isDark ? Color.white.opacity(0.9) : Color.black.opacity(0.82)
        return ZStack {
            VStack(spacing: size * 0.02) {
                Text(label)
                    .font(.system(size: size * 0.36, weight: .medium))
                if let caption {
                    Text(caption)
                        .font(.system(size: size * 0.14, weight: .medium))
                        .opacity(0.6)
                }
            }
            if let secondary {
                Text(secondary)
                    .font(.system(size: size * 0.2, weight: .medium))
                    .opacity(0.55)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(size * 0.12)
            }
        }
        .foregroundStyle(ink)
    }
}

/// A macOS window around scene content: traffic lights and a title.
struct SceneWindow<Content: View>: View {
    let title: String
    let palette: ThemePalette
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 6) {
                    TrafficLights()
                    Spacer(minLength: 0)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(palette.modalBackground)
        .clipShape(shape)
        .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
        .shadow(color: palette.shadow(0.18), radius: 16, y: 8)
    }
}

/// Close, minimise and zoom, in their system colours.
struct TrafficLights: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color(red: 1, green: 0.373, blue: 0.341))
            Circle().fill(Color(red: 0.996, green: 0.737, blue: 0.180))
            Circle().fill(Color(red: 0.157, green: 0.784, blue: 0.251))
        }
        .frame(width: 42, height: 10)
    }
}

/// A grey bar standing in for a line of text in someone else's window.
struct SceneTextLine: View {
    let width: CGFloat
    let palette: ThemePalette

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(palette.textTertiary.opacity(0.45))
            .frame(width: width, height: 6)
    }
}

/// The text insertion point, in the system's own colour.
struct SceneCaret: View {
    var height: CGFloat = 14
    var visible = true

    var body: some View {
        Rectangle()
            .fill(Self.color)
            .frame(width: 1.5, height: height)
            .opacity(visible ? 1 : 0)
    }

    static var color: Color {
        if #available(macOS 14.0, *) {
            return Color(nsColor: .textInsertionPointColor)
        }
        return Color(nsColor: .controlAccentColor)
    }

    /// Blinks twice a second, and is always on in a stop frame.
    static func isVisible(at time: SceneTime, duration: Double) -> Bool {
        time.t >= duration || time.t.truncatingRemainder(dividingBy: 1) < 0.6
    }
}

/// A made-up photo for demo clips: sky, sun and hills, drawn so no image files ship.
struct PhotoArt: View {
    enum Style {
        case mountains
        case sunset
    }

    let style: Style

    var body: some View {
        Canvas { context, size in
            let colors = palette
            let rect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(rect),
                with: .linearGradient(Gradient(colors: [colors.skyTop, colors.skyBottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
            )
            let sun = size.height * 0.24
            context.fill(Path(ellipseIn: CGRect(x: size.width * 0.66, y: size.height * 0.14, width: sun, height: sun)), with: .color(colors.sun))
            context.fill(hills(size, peaks: [0.18, 0.46, 0.72, 0.95], heights: [0.40, 0.26, 0.44, 0.32], base: 0.72), with: .color(colors.far))
            context.fill(hills(size, peaks: [0.1, 0.38, 0.64, 0.9], heights: [0.62, 0.56, 0.66, 0.58], base: 1), with: .color(colors.near))
        }
    }

    private var palette: (skyTop: Color, skyBottom: Color, sun: Color, far: Color, near: Color) {
        switch style {
        case .mountains:
            (Color(red: 0.49, green: 0.77, blue: 1), Color(red: 0.87, green: 0.94, blue: 1), Color(red: 1, green: 0.82, blue: 0.40),
             Color(red: 0.56, green: 0.75, blue: 0.50), Color(red: 0.30, green: 0.50, blue: 0.27))
        case .sunset:
            (Color(red: 1, green: 0.70, blue: 0.48), Color(red: 1, green: 0.88, blue: 0.76), Color(red: 1, green: 0.95, blue: 0.79),
             Color(red: 0.71, green: 0.54, blue: 0.82), Color(red: 0.42, green: 0.31, blue: 0.61))
        }
    }

    /// A ridge through the given peaks (x, y as shares of the size), closed along the bottom.
    private func hills(_ size: CGSize, peaks: [CGFloat], heights: [CGFloat], base: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height * base))
        for (x, y) in zip(peaks, heights) {
            path.addLine(to: CGPoint(x: size.width * x, y: size.height * y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height * base))
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }
}
