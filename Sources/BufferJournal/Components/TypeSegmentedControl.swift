import AppKit
import SwiftUI

/// Type filter: a track (radius 8) with a translucent orange thumb (radius 6) that slides between segments.
struct TypeSegmentedControl: View {
    let titles: [String]
    let selectedIndex: Int
    let palette: ThemePalette
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let segmentWidth = (geometry.size.width - 4) / CGFloat(max(titles.count, 1))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.segmentThumb)
                    .frame(width: segmentWidth)
                    .offset(x: segmentWidth * CGFloat(selectedIndex))
                    .padding(2)

                HStack(spacing: 0) {
                    ForEach(titles.indices, id: \.self) { index in
                        Button {
                            onSelect(index)
                        } label: {
                            Text(titles[index])
                                .font(.system(size: 11.5, weight: index == selectedIndex ? .semibold : .medium))
                                .foregroundStyle(index == selectedIndex ? palette.onAccent : palette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(width: segmentWidth, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
            }
        }
        .frame(height: 28)
        .background(palette.placeholderBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
