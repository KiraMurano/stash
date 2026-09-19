import Testing
@testable import BufferJournal

struct JournalKeysTests {
    @Test func listensToTheOpenJournalOverAnotherApp() {
        #expect(JournalKeys.shouldListen(intercepts: true, panelVisible: true, journalShown: true, stashActive: false, menuOpen: false))
    }

    @Test func letsTheKeysGoOtherwise() {
        #expect(!JournalKeys.shouldListen(intercepts: true, panelVisible: false, journalShown: true, stashActive: false, menuOpen: false))
        #expect(!JournalKeys.shouldListen(intercepts: true, panelVisible: true, journalShown: false, stashActive: false, menuOpen: false))
        #expect(!JournalKeys.shouldListen(intercepts: true, panelVisible: true, journalShown: true, stashActive: true, menuOpen: false))
        #expect(!JournalKeys.shouldListen(intercepts: true, panelVisible: true, journalShown: true, stashActive: false, menuOpen: true))
    }

    @Test func staysOutOfTheWayWithInterceptKeysOff() {
        #expect(!JournalKeys.shouldListen(intercepts: false, panelVisible: true, journalShown: true, stashActive: false, menuOpen: false))
    }
}
