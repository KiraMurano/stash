import Testing
@testable import BufferJournal

struct OnboardingSlidesTests {
    @Test func slidesComeInTheSpecOrderWithAccessLast() {
        #expect(OnboardingSlides.all.map(\.kind) == [.hero, .hotKey, .paste, .pin, .keys, .settings, .access])
    }

    @Test func theFifthSlideIsAboutKeys() {
        let fifth = OnboardingSlides.all[4]
        #expect(fifth.kind == .keys)
        #expect(fifth.word.ru == "КЛАВИШИ")
        #expect(fifth.word.en == "KEYS")
    }

    /// The spec keeps every text within 140 characters, so it takes at most three lines on a
    /// 560 × 360 panel and the block under the card never eats the card's room.
    @Test func wordsAreCapitalsAndTextsStayShort() {
        for slide in OnboardingSlides.all {
            #expect(slide.word.en == slide.word.en.uppercased())
            #expect(slide.word.ru == slide.word.ru.uppercased())
            #expect(slide.text.en.count <= 140, "\(slide.kind) EN is \(slide.text.en.count)")
            #expect(slide.text.ru.count <= 140, "\(slide.kind) RU is \(slide.text.ru.count)")
        }
    }

    @Test func onlyTheFirstSlidePlaysOnce() {
        #expect(OnboardingSlides.all.filter { !$0.loops }.map(\.kind) == [.hero])
    }

    @Test func theAccessSlideIsOnlyForThoseWithoutAccess() {
        #expect(OnboardingSlides.slides(hasAccess: false).count == 7)
        #expect(OnboardingSlides.slides(hasAccess: false).last?.kind == .access)

        let withAccess = OnboardingSlides.slides(hasAccess: true)
        #expect(withAccess.map(\.kind) == [.hero, .hotKey, .paste, .pin, .keys, .settings])
    }

    @Test func theAccessSlideStandsAlone() {
        #expect(OnboardingSlides.accessSlide.kind == .access)
        #expect(OnboardingSlides.all.last == OnboardingSlides.accessSlide)
    }

    @Test func aSlideIsIdentifiedByItsScene() {
        #expect(OnboardingSlides.all.map(\.id) == OnboardingSceneKind.allCases)
    }
}
