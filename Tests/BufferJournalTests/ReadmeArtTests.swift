import AppKit
import SwiftUI
import Testing
@testable import BufferJournal

/// The pieces the README's animations are assembled from, drawn by the journal's own views so
/// they look exactly like the app: rows, the list's top, the preview pane, the tour's keycaps
/// and the toast. (The pointer is drawn in the SVG: NSCursor has no image in a test process.) Run with a folder to write into:
///     README_ART_DIR=/tmp/stash-art swift test --filter ReadmeArtTests
/// then `Scripts/make_readme_art.py` puts them into docs/assets. Without README_ART_DIR the
/// test only checks that every piece renders.
@MainActor
struct ReadmeArtTests {
    private static let directory = ProcessInfo.processInfo.environment["README_ART_DIR"].map { URL(fileURLWithPath: $0) }
    private static let schemes: [(ColorScheme, String)] = [(.light, "light"), (.dark, "dark")]
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let icon = NSImage(contentsOf: root.appendingPathComponent("Resources/AppIcon.icns"))!
    private static let l10n = L10n(language: .english)

    private func write<V: View>(_ view: V, _ name: String, scheme: ColorScheme, suffix: String, scale: CGFloat = 2) throws {
        let renderer = ImageRenderer(
            content: view
                .environment(\.colorScheme, scheme)
                .environment(\.solidAccents, true)
                .environment(\.l10n, Self.l10n)
        )
        renderer.scale = scale
        let image = try #require(renderer.nsImage, "\(name) did not render")
        guard let directory = Self.directory else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bitmap = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent("\(name)-\(suffix).png"))
    }

    // MARK: The clips the animations show

    private var email: DemoClip { DemoClips.text("art-email", Localized(en: "hello@ozero.digital", ru: "hello@ozero.digital"), Self.l10n, at: 9, 12).pinned() }
    private var photo: DemoClip { DemoClips.image("art-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2) }
    private var url: DemoClip { DemoClips.text("art-url", Localized(en: "github.com/KiraMurano/stash", ru: "github.com/KiraMurano/stash"), Self.l10n, at: 14, 1) }
    private var release: DemoClip { DemoClips.text("art-release", Localized(en: "Stash 1.10 — release notes", ru: "Stash 1.10 — release notes"), Self.l10n, at: 13, 48) }
    private var invoice: DemoClip { DemoClips.file("art-invoice", Localized(en: "Invoice 0417.pdf", ru: "Invoice 0417.pdf"), bytes: 2_000_000, Self.l10n, at: 13, 20) }

    // MARK: Pieces

    /// The list's top as JournalView draws it: icon, wordmark, count, trash, then the type filter.
    private func listTop(count: Int, palette: ThemePalette) -> some View {
        let capHeight = NSFont.systemFont(ofSize: 28, weight: .heavy).capHeight
        return VStack(spacing: 0) {
            HStack(spacing: 2) {
                Image(nsImage: Self.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 32, height: 32)
                Text("Stash")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(palette.textPrimary)
                    .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - capHeight / 2 }
                Spacer(minLength: 0)
                Text("\(count)/20")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.textTertiary)
                    .padding(.trailing, 6)
                GlassIconButton(systemName: "trash", isDestructive: true, help: "", action: {})
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.top, 12)
            .padding(.bottom, 10)

            TypeSegmentedControl(
                titles: ["All", "Text", "Images", "Files"],
                selectedIndex: 0,
                palette: palette,
                onSelect: { _ in }
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(width: JournalView.Layout.sidebarWidth)
    }

    private func row(_ clip: DemoClip, selected: Bool = false, hovered: Bool = false, palette: ThemePalette) -> some View {
        DemoRow(clip: clip, isSelected: selected, isHovered: hovered, palette: palette)
            .padding(.horizontal, 10)
            .frame(width: JournalView.Layout.sidebarWidth)
    }

    private func section(_ title: String, palette: ThemePalette) -> some View {
        SectionHeader(title: title, palette: palette)
            .padding(.horizontal, 10)
            .frame(width: JournalView.Layout.sidebarWidth)
    }

    private func keycap(_ label: String, caption: String? = nil, pressed: Bool) -> some View {
        SceneKeycap(label: label, caption: caption, size: HotKeyScene.keySize, pressed: pressed)
            .padding(20)
    }

    /// The lockup for the README's top: the journal's own header, three times the size.
    private func wordmark(palette: ThemePalette) -> some View {
        let size: CGFloat = 84
        let capHeight = NSFont.systemFont(ofSize: size, weight: .heavy).capHeight
        return HStack(spacing: 6) {
            Image(nsImage: Self.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
            Text("Stash")
                .font(.system(size: size, weight: .heavy))
                .foregroundStyle(palette.textPrimary)
                .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - capHeight / 2 }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @Test func everyPieceRenders() throws {
        for (scheme, suffix) in Self.schemes {
            let palette = ThemePalette.scene(scheme)

            try write(listTop(count: 5, palette: palette), "list-top-5", scheme: scheme, suffix: suffix)
            try write(listTop(count: 3, palette: palette), "list-top-3", scheme: scheme, suffix: suffix)
            try write(section("Pinned", palette: palette), "section-pinned", scheme: scheme, suffix: suffix)
            try write(section("Today", palette: palette), "section-today", scheme: scheme, suffix: suffix)

            try write(row(email, palette: palette), "row-email", scheme: scheme, suffix: suffix)
            try write(row(photo, palette: palette), "row-photo", scheme: scheme, suffix: suffix)
            try write(row(photo, selected: true, palette: palette), "row-photo-selected", scheme: scheme, suffix: suffix)
            try write(row(url, palette: palette), "row-url", scheme: scheme, suffix: suffix)
            try write(row(url, selected: true, palette: palette), "row-url-selected", scheme: scheme, suffix: suffix)
            try write(row(url, hovered: true, palette: palette), "row-url-hovered", scheme: scheme, suffix: suffix)
            try write(row(url.pinned(), palette: palette), "row-url-pinned", scheme: scheme, suffix: suffix)
            try write(row(release, palette: palette), "row-release", scheme: scheme, suffix: suffix)
            try write(row(release, selected: true, palette: palette), "row-release-selected", scheme: scheme, suffix: suffix)
            try write(row(invoice, palette: palette), "row-invoice", scheme: scheme, suffix: suffix)

            let detail = CGSize(width: JournalView.Layout.width - JournalView.Layout.sidebarWidth, height: JournalView.Layout.height)
            try write(DemoDetailPane(clip: photo, palette: palette).frame(width: detail.width, height: detail.height), "detail-photo", scheme: scheme, suffix: suffix)
            try write(DemoDetailPane(clip: url, palette: palette).frame(width: detail.width, height: detail.height), "detail-url", scheme: scheme, suffix: suffix)

            for pressed in [false, true] {
                let state = pressed ? "-pressed" : ""
                try write(keycap("⌥", caption: "option", pressed: pressed), "key-option\(state)", scheme: scheme, suffix: suffix)
                try write(keycap("V", pressed: pressed), "key-v\(state)", scheme: scheme, suffix: suffix)
                try write(keycap("↓", pressed: pressed), "key-down\(state)", scheme: scheme, suffix: suffix)
                try write(keycap("⏎", pressed: pressed), "key-return\(state)", scheme: scheme, suffix: suffix)
            }

            try write(ToastOverlay(message: "Pasted").padding(30), "toast-pasted", scheme: scheme, suffix: suffix)
            try write(wordmark(palette: palette), "wordmark", scheme: scheme, suffix: suffix)
        }

        if let directory = Self.directory {
            let metrics: [String: Any] = [
                "keySize": HotKeyScene.keySize,
                "keyPadding": 20,
                "rowHeight": JournalView.Layout.rowHeight,
                "sidebarWidth": JournalView.Layout.sidebarWidth,
                "panel": [JournalView.Layout.width, JournalView.Layout.height],
                "cornerRadius": JournalView.Layout.cornerRadius,
            ]
            let data = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("metrics.json"))
        }
    }
}
