import CoreGraphics
import Testing
@testable import BufferJournal

/// Every scene is as long as its slide says, and every kind has a scene.
@MainActor
struct SceneDurationTests {
    private static let durations: [OnboardingSceneKind: Double] = [
        .hero: HeroScene.duration,
        .hotKey: HotKeyScene.duration,
        .paste: PasteScene.duration,
        .pin: PinScene.duration,
        .images: ImagesScene.duration,
        .keys: KeysScene.duration,
        .settings: SettingsScene.duration,
        .access: AccessScene.duration,
    ]

    @Test func sceneDurationsMatchTheSlides() {
        for slide in OnboardingSlides.all {
            #expect(Self.durations[slide.kind] == slide.duration, "\(slide.kind)")
        }
    }

    @Test func everyKindHasAScene() {
        #expect(Set(Self.durations.keys) == Set(OnboardingSceneKind.allCases))
        // Every scene but the first one draws on a canvas of its own.
        for kind in OnboardingSceneKind.allCases where kind != .hero {
            #expect(OnboardingSceneView.size(of: kind) != nil, "\(kind)")
        }
        #expect(OnboardingSceneView.size(of: .hero) == nil)
    }
}
