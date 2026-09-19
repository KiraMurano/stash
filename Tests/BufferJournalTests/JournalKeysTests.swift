import Testing
@testable import BufferJournal

struct JournalKeysTests {
    @Test func listensToTheOpenJournalOverAnotherApp() {
        #expect(JournalKeys.shouldListen(panelVisible: true, journalShown: true, stashActive: false, menuOpen: false))
    }

    @Test func letsTheKeysGoOtherwise() {
        #expect(!JournalKeys.shouldListen(panelVisible: false, journalShown: true, stashActive: false, menuOpen: false))
        #expect(!JournalKeys.shouldListen(panelVisible: true, journalShown: false, stashActive: false, menuOpen: false))
        #expect(!JournalKeys.shouldListen(panelVisible: true, journalShown: true, stashActive: true, menuOpen: false))
        #expect(!JournalKeys.shouldListen(panelVisible: true, journalShown: true, stashActive: false, menuOpen: true))
    }
}
