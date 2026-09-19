import AppKit
import SwiftUI

struct GlassIconButton: View {
    let systemName: String
    var isDestructive = false
    var tint: Color?
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(TranslucentButtonStyle(tone: tint != nil ? .accent : (isDestructive ? .destructive : .neutral), cornerRadius: 8))
        .help(help)
        // Icon-only: VoiceOver reads the tooltip text instead of the symbol name.
        .accessibilityLabel(help)
    }
}
