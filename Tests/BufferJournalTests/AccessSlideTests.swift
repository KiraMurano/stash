import Foundation
import Testing
@testable import BufferJournal

/// The access screen stands in for the system here: `AccessibilityAccess` is a struct of closures.
@MainActor
final class AccessSpy {
    var granted: Bool
    private(set) var requests = 0

    init(granted: Bool) {
        self.granted = granted
    }

    var access: AccessibilityAccess {
        AccessibilityAccess(
            isGranted: { [self] in granted },
            request: { [self] in
                requests += 1
                granted = true
            }
        )
    }
}

/// The ДОСТУП slide: the texts it took from the access screen, its button and its silent keys.
@MainActor
struct AccessSlideTests {
    private func defaults() -> UserDefaults {
        let name = "AccessSlideTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func controller(granted: Bool) -> (OnboardingController, AccessSpy, AccessGate) {
        let spy = AccessSpy(granted: granted)
        let gate = AccessGate(access: spy.access)
        return (OnboardingController(defaults: defaults(), access: gate), spy, gate)
    }

    private func onAccessSlide(granted: Bool = false) -> (OnboardingController, AccessSpy, AccessGate) {
        let (controller, spy, gate) = controller(granted: granted)
        controller.present(replay: false)
        while !controller.isLast {
            controller.next()
        }
        return (controller, spy, gate)
    }

    @Test func theTextsAreTheAccessScreensOwn() {
        let ru = L10n(language: .russian)
        let en = L10n(language: .english)
        #expect(AccessSlide.titleTail(ru) == " нужен Универсальный доступ")
        #expect(AccessSlide.titleTail(en) == " needs Accessibility access")
        #expect(AccessSlide.line(ru) == "Stash вставляет клип, нажимая ⌘V за вас. Без Универсального доступа macOS этого не разрешит.")
        #expect(AccessSlide.line(en) == "Stash pastes by pressing ⌘V for you. macOS won't allow it without Accessibility access.")
        #expect(AccessSlide.hint(ru).hasPrefix("Stash уже в списке и включён"))
        #expect(AccessSlide.hint(en).hasPrefix("Stash is already in the list"))
        #expect(AccessSlide.buttonTitle(ru) == "Открыть настройки")
        #expect(AccessSlide.buttonTitle(en) == "Open Settings")
        #expect(AccessSlide.grantedTitle(ru) == "Доступ включён")
        #expect(AccessSlide.grantedTitle(en) == "Access granted")
    }

    @Test func theCardHasAButtonOnlyInTheTutorial() {
        #expect(AccessSlide.showsCardButton(isAccessOnly: false))
        #expect(!AccessSlide.showsCardButton(isAccessOnly: true))
    }

    @Test func theSlideIsTheLastOneWithoutAccess() {
        let (controller, _, gate) = onAccessSlide()
        #expect(controller.slide.kind == .access)
        #expect(controller.isLast)
        #expect(!gate.isGranted)
    }

    @Test func theButtonAsksTheGateAndGrantedAccessShowsUp() {
        let (controller, spy, gate) = onAccessSlide()
        controller.requestAccess()
        #expect(spy.requests == 1)
        // The gate polls once a second while the panel is up; a refresh is what its timer does.
        gate.refresh()
        #expect(gate.isGranted)
    }

    @Test func aloneItIsTheOnlySlideAndItsMainButtonAsksForAccess() {
        let (controller, spy, _) = controller(granted: false)
        controller.presentAccessOnly()
        #expect(controller.isAccessOnly)
        #expect(controller.slides.count == 1)
        #expect(controller.slide.kind == .access)
        controller.primaryAction()
        #expect(spy.requests == 1)
    }
}
