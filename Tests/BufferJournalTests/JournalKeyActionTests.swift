import Testing
@testable import BufferJournal

struct JournalKeyActionTests {
    @Test func arrowsMoveTheSelection() {
        #expect(JournalKeyAction.resolve(.up, dialogShown: false, hasSelection: true) == .moveUp)
        #expect(JournalKeyAction.resolve(.down, dialogShown: false, hasSelection: true) == .moveDown)
    }

    @Test func returnPastesOnlyASelectedClip() {
        #expect(JournalKeyAction.resolve(.enter, dialogShown: false, hasSelection: true) == .paste)
        #expect(JournalKeyAction.resolve(.enter, dialogShown: false, hasSelection: false) == .ignore)
    }

    @Test func escapeClosesTheDialogBeforeThePanel() {
        #expect(JournalKeyAction.resolve(.escape, dialogShown: true, hasSelection: true) == .closeDialog)
        #expect(JournalKeyAction.resolve(.escape, dialogShown: false, hasSelection: true) == .closePanel)
    }

    @Test func aDialogIgnoresArrowsAndReturn() {
        for key in [JournalKey.up, .down, .enter] {
            #expect(JournalKeyAction.resolve(key, dialogShown: true, hasSelection: true) == .ignore)
        }
    }
}
