import AppKit
import SwiftUI
import Testing
@testable import BufferJournal

/// PNGs of the tutorial for a person to look at. Run with a folder to write into:
///     SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests
/// Without SNAPSHOT_DIR these tests only check that every view renders.
@MainActor
struct SnapshotTests {
    private static let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
    private static let schemes: [(ColorScheme, String)] = [(.light, "light"), (.dark, "dark")]
    /// The panel at its smallest, its default and a large size.
    private static let sizes = [
        CGSize(width: 560, height: 360),
        CGSize(width: 640, height: 440),
        CGSize(width: 900, height: 600),
    ]

    private func render<V: View>(_ view: V, name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.nsImage, "\(name) did not render")
        guard let directory = Self.directory else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bitmap = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent("\(name).png"))
    }

    /// An Accessibility gate that answers what the test wants and never touches the system.
    private func gate(granted: Bool) -> AccessGate {
        AccessGate(access: AccessibilityAccess(isGranted: { granted }, request: {}))
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "SnapshotTests-\(UUID().uuidString)")!
    }

    /// The tour opened on one of its own slides. With access granted, closing it never hands
    /// over to the access screen, which is a screen of its own and has its own test.
    private func controller(on kind: OnboardingSceneKind) -> (OnboardingController, AccessGate) {
        let access = gate(granted: true)
        let controller = OnboardingController(defaults: defaults(), access: access)
        controller.present(replay: true)
        while controller.slide.kind != kind, !controller.isLast { controller.next() }
        return (controller, access)
    }

    private func accessOnlyController() -> (OnboardingController, AccessGate) {
        let access = gate(granted: false)
        let controller = OnboardingController(defaults: defaults(), access: access)
        controller.presentAccessOnly()
        return (controller, access)
    }

    private func frame(_ controller: OnboardingController, _ access: AccessGate, scheme: ColorScheme, size: CGSize) -> some View {
        OnboardingView(
            controller: controller,
            access: access,
            l10n: L10n(language: .russian),
            onOpenSettings: {},
            onClosePanel: {}
        )
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, scheme)
        .environment(\.scenesHoldStopFrame, true)
    }

    /// The whole tutorial on three slides, at three panel sizes.
    @Test func tutorialFrame() throws {
        for (scheme, name) in Self.schemes {
            for kind in [OnboardingSceneKind.hero, .keys, .pin] {
                for size in Self.sizes {
                    let (controller, access) = controller(on: kind)
                    try render(frame(controller, access, scheme: scheme, size: size), name: "frame-\(kind.rawValue)-\(Int(size.width))-\(name)")
                }
            }
        }
    }

    /// The access screen: no bars, no card, and "Открыть настройки" at the bottom.
    @Test func accessOnlyFrame() throws {
        for (scheme, name) in Self.schemes {
            for size in Self.sizes {
                let (controller, access) = accessOnlyController()
                try render(frame(controller, access, scheme: scheme, size: size), name: "frame-access-only-\(Int(size.width))-\(name)")
            }
        }
    }
}

extension SnapshotTests {
    /// Every scene's stop frame and its middle, on the card's surface, in both themes and languages.
    @Test func sceneFrames() throws {
        for (scheme, schemeName) in Self.schemes {
            for (language, languageName) in [(ResolvedLanguage.russian, "ru"), (.english, "en")] {
                for slide in OnboardingSlides.all + [OnboardingSlides.accessSlide] {
                    let area = OnboardingSceneView.size(of: slide.kind) ?? CGSize(width: 600, height: 309)
                    let palette = ThemePalette.scene(scheme)
                    for (time, timeName) in [(SceneTime.end(of: slide.duration), "end"), (SceneTime(t: slide.duration * 0.4, rewind: 0), "mid")] {
                        let view = OnboardingSceneView.canvas(for: slide.kind, at: time, in: area)
                            .background(slide.kind == .hero ? AnyView(OnboardingColors(isDark: scheme == .dark).field) : AnyView(palette.listSurface))
                            .environment(\.colorScheme, scheme)
                            .environment(\.l10n, L10n(language: language))
                            .environment(\.solidAccents, true)
                        try render(view, name: "scene-\(slide.kind.rawValue)-\(timeName)-\(languageName)-\(schemeName)")
                    }
                }
            }
        }
    }
}
