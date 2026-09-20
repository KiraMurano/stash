import Testing
@testable import BufferJournal

struct UpdateTextsTests {
    private let ru = L10n(language: .russian)
    private let en = L10n(language: .english)

    @Test func megabytesFollowTheLanguage() {
        #expect(ru.megabytes(4_404_019) == "4,2 МБ")
        #expect(en.megabytes(4_404_019) == "4.2 MB")
    }

    @Test func aSmallImageStillShowsAFraction() {
        #expect(en.megabytes(102_400) == "0.1 MB")
    }

    @Test func theFooterSaysWhatIsInstalledNow() {
        #expect(ru.updateCurrent("1.26", bytes: 4_404_019) == "Сейчас 1.26 · 4,2 МБ")
        #expect(en.updateCurrent("1.26", bytes: 4_404_019) == "Now 1.26 · 4.2 MB")
    }

    @Test func progressIsWholePercent() {
        #expect(ru.updateDownloading(0.404) == "Загрузка… 40 %")
        #expect(en.updateDownloading(1) == "Downloading… 100 %")
    }

    @Test func withoutAReleaseTheLineNamesTheVersionAlone() {
        #expect(ru.updateCurrent("1.27") == "Сейчас 1.27")
        #expect(en.updateCurrent("1.27") == "Now 1.27")
    }

    @Test func everyAnswerToACheckHasItsOwnSentence() {
        let answers = [ru.updateChecking, ru.updateUpToDate, ru.updateFailure(.network)]
        #expect(Set(answers).count == 3)
    }

    @Test func everyFailureHasItsOwnSentence() {
        #expect(ru.updateFailure(.network) != ru.updateFailure(.notWritable))
        #expect(ru.updateFailure(.signature("x")) != ru.updateFailure(.install("x")))
        #expect(!ru.updateFailure(.signature("x")).contains("x"))
    }

    @Test func theMenuNamesTheVersionItOffers() {
        #expect(StatusMenuTitles(l10n: ru).updateTo("1.27") == "Обновить до 1.27")
        #expect(StatusMenuTitles(l10n: en).updateTo("1.27") == "Update to 1.27")
    }
}
