import AppKit
import SwiftUI

struct ImagePreviewView: View {
    let image: NSImage
    @ObservedObject var settings: AppSettings
    let onPaste: () -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPasteHovered = false

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            palette.windowBackground

            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)

            Button(action: onPaste) {
                HStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 13, weight: .semibold))
                    Text(settings.pasteOnSelection ? "Вставить" : "Скопировать")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(isPasteHovered ? palette.cardHoverBackground : palette.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                )
                .shadow(color: palette.shadow(0.12), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isPasteHovered = hovering
                }
            }
        }
        .frame(minWidth: 320, minHeight: 240)
        .preferredColorScheme(settings.themeMode.colorScheme)
        .onExitCommand(perform: onClose)
    }
}

/// Titled panel that does not activate the app, so "Paste" still targets the previously focused app.
final class ImagePreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
