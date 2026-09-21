import Testing
@testable import BufferJournal

struct PanelContentTests {
    @Test func theTutorialCoversEveryOtherScreen() {
        let content = JournalKeys.content(
            onboardingPresented: true,
            onboardingIsAccess: false,
            aboutPresented: true,
            updatePresented: true,
            accessGranted: true
        )
        #expect(content == .onboarding)
    }

    @Test func theAboutScreenCoversTheUpdateScreen() {
        let content = JournalKeys.content(
            onboardingPresented: false,
            onboardingIsAccess: false,
            aboutPresented: true,
            updatePresented: true,
            accessGranted: true
        )
        #expect(content == .about)
    }

    @Test func withoutAccessTheJournalGivesWayToTheAccessSlide() {
        let content = JournalKeys.content(
            onboardingPresented: false,
            onboardingIsAccess: false,
            aboutPresented: false,
            updatePresented: false,
            accessGranted: false
        )
        #expect(content == .access)
    }

    @Test func theAboutScreenTakesNoKeys() {
        let mode = JournalKeys.mode(
            intercepts: true,
            panelVisible: true,
            content: .about,
            stashActive: false,
            menuOpen: false
        )
        #expect(mode == .off)
    }
}
