import Testing
@testable import BufferJournal

struct JournalKeysTests {
    @Test func theOpenJournalTakesItsOwnKeys() {
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, accessGranted: true, stashActive: false, menuOpen: false) == .journal)
    }

    @Test func theAccessScreenTakesNone() {
        // The user is on their way to System Settings, where Return and Esc are theirs.
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, accessGranted: false, stashActive: false, menuOpen: false) == .off)
    }

    @Test func letsTheKeysGoOtherwise() {
        #expect(JournalKeys.mode(intercepts: true, panelVisible: false, accessGranted: true, stashActive: false, menuOpen: false) == .off)
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, accessGranted: true, stashActive: true, menuOpen: false) == .off)
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, accessGranted: true, stashActive: false, menuOpen: true) == .off)
    }

    @Test func staysOutOfTheWayWithInterceptKeysOff() {
        #expect(JournalKeys.mode(intercepts: false, panelVisible: true, accessGranted: true, stashActive: false, menuOpen: false) == .off)
    }
}
