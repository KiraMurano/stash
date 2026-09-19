import SwiftUI

/// "Pinned", "Today" and the other headings between groups of rows.
struct SectionHeader: View {
    let title: String
    let palette: ThemePalette

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.textTertiary)
            .padding(.leading, 8)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .leading)
    }
}
