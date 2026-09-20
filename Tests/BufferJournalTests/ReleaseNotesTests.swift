import Testing
@testable import BufferJournal

struct ReleaseNotesTests {
    @Test func aDashedLineBecomesAnItem() {
        let notes = ReleaseNotes.parse("- Журнал открывается у курсора.")
        #expect(notes == [ReleaseNote(id: 0, kind: .item, text: "Журнал открывается у курсора.")])
    }

    @Test func anAsteriskIsAnItemToo() {
        #expect(ReleaseNotes.parse("* Второй пункт.").first?.kind == .item)
    }

    @Test func aPlainLineStaysAParagraph() {
        let notes = ReleaseNotes.parse("Подпись приложения сменилась.")
        #expect(notes == [ReleaseNote(id: 0, kind: .paragraph, text: "Подпись приложения сменилась.")])
    }

    @Test func headingsLoseTheirHashes() {
        #expect(ReleaseNotes.parse("## Что нового").first?.text == "Что нового")
        #expect(ReleaseNotes.parse("## Что нового").first?.kind == .paragraph)
    }

    @Test func emptyLinesAndWindowsEndingsAreDropped() {
        let notes = ReleaseNotes.parse("- Первый\r\n\r\n- Второй\r\n")
        #expect(notes.map(\.text) == ["Первый", "Второй"])
        #expect(notes.map(\.id) == [0, 1])
    }

    @Test func nothingInNothingOut() {
        #expect(ReleaseNotes.parse("   \n\n").isEmpty)
    }
}
