import Foundation
import Testing
@testable import BufferJournal

/// A stand-in for the system permission behind a real `AccessGate`.
@MainActor
final class FakeAccessGate {
    var granted: Bool
    private(set) var requests = 0

    /// Built on first use so the gate reads `granted` as the test set it.
    private(set) lazy var gate = AccessGate(
        access: AccessibilityAccess(
            isGranted: { [unowned self] in granted },
            request: { [unowned self] in requests += 1 }
        )
    )

    init(granted: Bool) {
        self.granted = granted
    }
}

@MainActor
struct OnboardingControllerTests {
    /// A fresh domain per test: Swift Testing makes a new instance for each one.
    private let defaults: UserDefaults = {
        let name = "OnboardingControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()

    private func make(granted: Bool = true) -> (OnboardingController, FakeAccessGate) {
        let access = FakeAccessGate(granted: granted)
        return (OnboardingController(defaults: defaults, access: access.gate), access)
    }

    @Test func showsOnFirstLaunchUntilClosed() {
        let (controller, _) = make()
        #expect(controller.shouldShowOnLaunch)
        controller.present(replay: false)
        controller.close()
        #expect(!controller.shouldShowOnLaunch)
        #expect(defaults.integer(forKey: OnboardingController.seenVersionKey) == OnboardingController.currentVersion)
    }

    @Test func quittingMidwayShowsItAgain() {
        let (controller, _) = make()
        controller.present(replay: false)
        controller.next()
        #expect(controller.shouldShowOnLaunch)
    }

    @Test func aReplayDoesNotMarkItSeen() {
        let (controller, _) = make()
        controller.present(replay: true)
        controller.close()
        #expect(controller.shouldShowOnLaunch)
    }

    @Test func theMenuDuringTheFirstShowingRestartsItAndStillMarksItSeen() {
        let (controller, _) = make()
        controller.present(replay: false)
        controller.next()
        controller.present(replay: true)
        #expect(controller.index == 0)
        controller.close()
        #expect(!controller.shouldShowOnLaunch)
    }

    @Test func theTourIsTheSameWithAccessOrWithout() {
        // The access screen is not one of the tour's slides: it stands on its own.
        for granted in [true, false] {
            let (controller, _) = make(granted: granted)
            controller.present(replay: false)
            #expect(controller.slides.map(\.kind) == OnboardingSlides.all.map(\.kind))
            #expect(!controller.isAccessOnly)
            #expect(!controller.slides.contains { $0.kind == .access })
        }
    }

    /// Тур закрывается в никуда: журнал после него не открывается, и экран доступа
    /// тур больше не зовёт — его поднимает панель, когда её просят показаться.
    @Test func theTourClosesIntoNothingWithoutAccess() {
        let (controller, _) = make(granted: false)
        controller.present(replay: false)
        controller.close()

        #expect(!controller.isPresented)
        #expect(!controller.isAccessOnly)
    }

    @Test func slidesStayInBoundsAndEveryEntryRestartsTheScene() {
        let (controller, _) = make()
        controller.present(replay: false)
        let run = controller.run
        controller.back()
        #expect(controller.index == 0)
        #expect(controller.run == run)
        for _ in 0..<20 { controller.next() }
        #expect(controller.isLast)
        #expect(controller.isPresented)
        #expect(controller.run == run + controller.slides.count - 1)
        controller.back()
        #expect(controller.index == controller.slides.count - 2)
    }

    @Test func startOnTheLastSlideCloses() {
        let (controller, _) = make()
        controller.present(replay: false)
        for _ in 0..<(controller.slides.count - 1) { controller.primaryAction() }
        #expect(controller.isPresented)
        controller.primaryAction()
        #expect(!controller.isPresented)
    }

    @Test func theAccessScreenShowsOnItsOwnWithoutRecordingAnything() {
        let (controller, _) = make(granted: false)
        controller.presentAccessOnly()
        #expect(controller.isPresented)
        #expect(controller.isAccessOnly)
        #expect(controller.slides.map(\.kind) == [.access])
        #expect(controller.isLast)
        controller.close()
        #expect(controller.shouldShowOnLaunch)
        #expect(!controller.isAccessOnly)
        #expect(!controller.isPresented)
    }

    @Test func theAccessScreenIsPointlessWithAccess() {
        let (controller, _) = make(granted: true)
        controller.presentAccessOnly()
        #expect(!controller.isPresented)
    }

    @Test func theButtonOfTheLoneAccessScreenAsksForAccess() {
        let (controller, access) = make(granted: false)
        controller.presentAccessOnly()
        controller.primaryAction()
        #expect(access.requests == 1)
        #expect(controller.isPresented)
    }

    @Test func theMenuOpensTheTutorialOverTheLoneAccessScreen() {
        let (controller, _) = make(granted: false)
        controller.presentAccessOnly()
        controller.present(replay: true)
        #expect(!controller.isAccessOnly)
        #expect(controller.slides.count == OnboardingSlides.all.count)
        #expect(controller.index == 0)
    }

    @Test func theCardButtonAsksForAccess() {
        let (controller, access) = make(granted: false)
        controller.present(replay: false)
        controller.requestAccess()
        #expect(access.requests == 1)
    }

    @Test func showingThePanelAgainRestartsTheSceneOnlyWhileOpen() {
        let (controller, _) = make()
        controller.restartScene()
        #expect(controller.run == 0)
        controller.present(replay: false)
        controller.restartScene()
        #expect(controller.run == 2)
    }
}
