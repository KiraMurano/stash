import SwiftUI

/// The card's content: the slide's scene, fitted into the card and run by its clock.
struct OnboardingSceneView: View {
    let slide: OnboardingSlide
    let still: Bool

    var body: some View {
        GeometryReader { geometry in
            SceneClock(duration: slide.duration, loops: slide.loops, still: still) { time in
                Self.canvas(for: slide.kind, at: time, in: geometry.size)
            }
        }
        .environment(\.solidAccents, true)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Each scene's own canvas, fitted to what it shows; the card hugs it. The first slide has no
    /// canvas: it lays its logo out by whatever room it gets. Every scene keeps the placeholder
    /// size until its own task gives it the one from the spec.
    static func size(of kind: OnboardingSceneKind) -> CGSize? {
        switch kind {
        case .hero: nil
        case .hotKey: HotKeyScene.size
        case .paste: PasteScene.size
        case .pin: PinScene.size
        case .images: ImagesScene.size
        case .keys: KeysScene.size
        case .settings: OnboardingLayout.sceneSize
        case .access: OnboardingLayout.sceneSize
        }
    }

    /// The scene fitted into `area`, grown or shrunk to fill it and keeping its proportions.
    @ViewBuilder
    static func canvas(for kind: OnboardingSceneKind, at time: SceneTime, in area: CGSize) -> some View {
        if let size = size(of: kind) {
            scene(kind, at: time, area: area)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .scaleEffect(OnboardingLayout.sceneScale(size, in: area))
                .frame(width: area.width, height: area.height)
        } else {
            scene(kind, at: time, area: area)
                .frame(width: area.width, height: area.height)
        }
    }

    @ViewBuilder
    private static func scene(_ kind: OnboardingSceneKind, at time: SceneTime, area: CGSize) -> some View {
        switch kind {
        case .hero: HeroScene(time: time, area: area)
        case .hotKey: HotKeyScene(time: time)
        case .paste: PasteScene(time: time)
        case .pin: PinScene(time: time)
        case .images: ImagesScene(time: time)
        case .keys: KeysScene(time: time)
        case .settings: Color.clear
        case .access: Color.clear
        }
    }
}
