import Testing
@testable import BufferJournal

struct AboutTextsTests {
    private let ru = L10n(language: .russian)
    private let en = L10n(language: .english)

    @Test func theMenuItemNamesTheApp() {
        #expect(StatusMenuTitles(l10n: ru).about == "О приложении")
        #expect(StatusMenuTitles(l10n: en).about == "About Stash")
    }

    @Test func theScreenSaysWhoMadeIt() {
        #expect(ru.aboutMadeIn == "Сделано в")
        #expect(en.aboutMadeIn == "Made in")
    }

    @Test func theButtonAsksForFeedback() {
        #expect(ru.aboutFeedback == "Обратная связь")
        #expect(en.aboutFeedback == "Send Feedback")
    }

    @Test func everyItemInTheMenuHasATitleOfItsOwn() {
        let titles = StatusMenuTitles(l10n: ru)
        let all = [titles.openStash, titles.tutorial, titles.about, titles.clearHistory, titles.quit]
        #expect(Set(all).count == all.count)
    }
}
