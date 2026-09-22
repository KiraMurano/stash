import AppKit
import SwiftUI
import Testing
@testable import BufferJournal

/// The 1280 × 640 card GitHub shows for the repository, and every chat unfurls from its link:
/// the journal itself, whole, on the same desktop the README's animations stand on. Drawn by
/// JournalMiniature, so the card is the app rather than a picture of it. Run with a folder to
/// write into:
///     SOCIAL_DIR=docs/assets swift test --filter SocialPreviewTests
/// Without SOCIAL_DIR the test only checks that the card draws.
@MainActor
struct SocialPreviewTests {
    private static let directory = ProcessInfo.processInfo.environment["SOCIAL_DIR"].map { URL(fileURLWithPath: $0) }
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    /// What GitHub asks for; other previews crop from the middle of it.
    private static let card = CGSize(width: 1280, height: 640)
    /// The journal a little larger than life, with room left for its shadow.
    private static let panelScale: CGFloat = 1.1
    private static let schemes: [(ColorScheme, String)] = [(.light, "light"), (.dark, "dark")]

    /// The desktop, in the colours make_readme_art.py paints it with.
    private static func wall(_ scheme: ColorScheme) -> [NSColor] {
        scheme == .light
            ? [rgb(0x8fb6e8), rgb(0xc9a7d9), rgb(0xf2c6a0)]
            : [rgb(0x1d2a44), rgb(0x3a2346), rgb(0x4a2f25)]
    }

    private static func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                green: CGFloat((hex >> 8) & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255,
                alpha: alpha)
    }

    /// The journal at `panelScale`, drawn at twice that again so the card can downsample it.
    private func journal(_ scheme: ColorScheme, selected: Int) throws -> NSImage {
        NSApplication.shared.applicationIconImage = NSImage(contentsOf: Self.root.appendingPathComponent("Resources/AppIcon.icns"))
        let renderer = ImageRenderer(
            content: JournalMiniature(palette: .scene(scheme), selected: selected)
                .environment(\.colorScheme, scheme)
                .environment(\.solidAccents, true)
                .environment(\.l10n, L10n(language: .english))
        )
        renderer.scale = 2 * Self.panelScale
        return try #require(renderer.nsImage, "the journal did not render")
    }

    /// A light blob in the top left, a warm one behind the journal, and the glass on top.
    private func blob(_ color: NSColor, at center: NSPoint, radius: CGFloat) {
        NSGradient(starting: color, ending: color.withAlphaComponent(0))?
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
    }

    private func draw(_ scheme: ColorScheme, selected: Int) throws -> NSBitmapImageRep {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(Self.card.width), pixelsHigh: Int(Self.card.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        rep.size = Self.card

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high

        let bounds = NSRect(origin: .zero, size: Self.card)
        NSGradient(colors: Self.wall(scheme))?.draw(in: bounds, angle: -45)
        blob(Self.rgb(0xffffff, scheme == .light ? 0.40 : 0.16), at: NSPoint(x: 210, y: 560), radius: 300)
        blob(Self.rgb(0xf46a25, 0.55), at: NSPoint(x: 1010, y: 140), radius: 320)

        let size = NSSize(width: JournalView.Layout.width * Self.panelScale,
                          height: JournalView.Layout.height * Self.panelScale)
        let frame = NSRect(x: (Self.card.width - size.width) / 2,
                           y: (Self.card.height - size.height) / 2,
                           width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.shadowBlurRadius = 34
        shadow.set()
        try journal(scheme, selected: selected).draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1,
                                 respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()

        return rep
    }

    @Test func cardDraws() throws {
        for (scheme, name) in Self.schemes {
          for (selected, clip) in [(0, "text"), (1, "photo")] {
            let rep = try draw(scheme, selected: selected)
            #expect(rep.pixelsWide == 1280 && rep.pixelsHigh == 640)
            guard let directory = Self.directory else { continue }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let png = try #require(rep.representation(using: .png, properties: [:]))
            try png.write(to: directory.appendingPathComponent("social-preview-\(clip)-\(name).png"))
          }
        }
    }
}
