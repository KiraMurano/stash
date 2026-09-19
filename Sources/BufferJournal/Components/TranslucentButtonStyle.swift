import AppKit
import SwiftUI

/// Translucent button: a tinted fill that deepens on hover (shadcn-style), more on press.
/// Neutral is grey, accent is orange with an orange label, destructive turns red on hover.
struct TranslucentButtonStyle: ButtonStyle {
    enum Tone {
        case neutral
        case accent
        case destructive
        /// Accent sitting on an orange surface (the selected row): in the Stash themes it turns
        /// white with an orange glyph; otherwise it is a regular accent.
        case accentOnAccent
    }

    var tone: Tone = .neutral
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        TranslucentButtonBody(configuration: configuration, tone: tone, cornerRadius: cornerRadius)
    }

    private struct TranslucentButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let tone: Tone
        let cornerRadius: CGFloat

        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.solidAccents) private var solidAccents
        @State private var isHovered = false

        private var palette: ThemePalette {
            ThemePalette(colorScheme: colorScheme, solid: solidAccents)
        }

        var body: some View {
            configuration.label
                .foregroundStyle(foreground)
                .background {
                    // Opaque buttons in the Stash themes need an edge to read on opaque surfaces.
                    // The shadow sits on the plate only, so glyphs and labels stay crisp.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fill)
                        .shadow(
                            color: palette.solid ? palette.controlShadow : .clear,
                            radius: ThemePalette.controlShadowRadius,
                            y: 1
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }

        private var level: Double {
            configuration.isPressed ? 2 : (isHovered ? 1 : 0)
        }

        private var foreground: Color {
            if palette.solid {
                switch tone {
                case .accent: return .white
                case .accentOnAccent: return ThemePalette.orange
                case .destructive where isHovered: return .white
                case .neutral, .destructive: return palette.iconOpacity(0.78)
                }
            }
            switch tone {
            case .accent, .accentOnAccent: return palette.accentText
            case .destructive: return isHovered ? Color.red.opacity(0.9) : palette.iconOpacity(0.7)
            case .neutral: return palette.iconOpacity(isHovered ? 0.85 : 0.7)
            }
        }

        private var fill: Color {
            if palette.solid {
                switch tone {
                case .accent:
                    return ThemePalette.darken(ThemePalette.orange, by: 0.08 * level)
                case .accentOnAccent:
                    // Soft off-white plate on the orange row, in both looks.
                    return Color(white: 0.96 - 0.04 * level)
                case .destructive where isHovered:
                    return ThemePalette.darken(ThemePalette.solidDestructive, by: 0.08 * (level - 1))
                case .neutral, .destructive:
                    return palette.solidControl(level)
                }
            }
            switch tone {
            case .accent, .accentOnAccent:
                return ThemePalette.orange.opacity((palette.isDark ? 0.28 : 0.18) + 0.08 * level)
            case .destructive where isHovered:
                return Color.red.opacity((palette.isDark ? 0.2 : 0.12) + 0.06 * (level - 1))
            case .neutral, .destructive:
                return palette.iconOpacity((palette.isDark ? 0.10 : 0.06) + 0.05 * level)
            }
        }
    }
}
