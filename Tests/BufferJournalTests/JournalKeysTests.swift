import Testing
@testable import BufferJournal

struct JournalKeysTests {
    @Test func theOpenJournalTakesItsOwnKeys() {
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: .journal, stashActive: false, menuOpen: false) == .journal)
    }

    @Test func theTutorialTakesNone() {
        // The tutorial is turned with the mouse: every key stays with the app underneath.
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: .onboarding, stashActive: false, menuOpen: false) == .off)
    }

    @Test func theAccessScreenTakesNone() {
        // The user is on their way to System Settings, where Return and Esc are theirs.
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: .access, stashActive: false, menuOpen: false) == .off)
    }

    @Test func letsTheKeysGoOtherwise() {
        for content in [JournalKeys.PanelContent.journal, .onboarding] {
            #expect(JournalKeys.mode(intercepts: true, panelVisible: false, content: content, stashActive: false, menuOpen: false) == .off)
            #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: content, stashActive: true, menuOpen: false) == .off)
            #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: content, stashActive: false, menuOpen: true) == .off)
        }
    }

    @Test func staysOutOfTheWayWithInterceptKeysOff() {
        #expect(JournalKeys.mode(intercepts: false, panelVisible: true, content: .journal, stashActive: false, menuOpen: false) == .off)
        #expect(JournalKeys.mode(intercepts: false, panelVisible: true, content: .onboarding, stashActive: false, menuOpen: false) == .off)
    }
}
