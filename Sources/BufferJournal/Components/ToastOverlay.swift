import AppKit
import SwiftUI

struct ToastOverlay: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.solidAccents) private var solidAccents

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: solidAccents)
    }

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(palette.modalBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(palette.borderSelected, lineWidth: 1)
            )
            .shadow(color: palette.shadow(0.12), radius: 14, y: 6)
    }
}
