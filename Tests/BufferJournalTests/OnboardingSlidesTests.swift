import Testing
@testable import BufferJournal

struct OnboardingSlidesTests {
    @Test func theTourRunsInOrderAndEndsOnPinning() {
        #expect(OnboardingSlides.all.map(\.kind) == [.hero, .hotKey, .paste, .keys, .pin])
    }

    /// The keys slide continues the paste slide: the same act, done from the keyboard.
    @Test func theKeysSlideFollowsThePasteSlide() {
        let kinds = OnboardingSlides.all.map(\.kind)
        #expect(kinds.firstIndex(of: .keys) == kinds.firstIndex(of: .paste).map { $0 + 1 })
    }

    /// The spec keeps every text within 140 characters, so it takes at most three lines on a
    /// 560 × 360 panel and the block under the card never eats the card's room.
    @Test func wordsAreCapitalsAndTextsStayShort() {
        for slide in OnboardingSlides.all + [OnboardingSlides.accessSlide] {
            #expect(slide.word.en == slide.word.en.uppercased())
            #expect(slide.word.ru == slide.word.ru.uppercased())
            #expect(slide.text.en.count <= 140, "\(slide.kind) EN is \(slide.text.en.count)")
            #expect(slide.text.ru.count <= 140, "\(slide.kind) RU is \(slide.text.ru.count)")
        }
    }

    @Test func onlyTheFirstSlidePlaysOnce() {
        #expect(OnboardingSlides.all.filter { !$0.loops }.map(\.kind) == [.hero])
    }

    /// The access screen stands apart: it is never one of the tour's slides, because it shows
    /// whenever Stash lacks access, tour or no tour.
    @Test func theAccessScreenIsNotPartOfTheTour() {
        #expect(OnboardingSlides.accessSlide.kind == .access)
        #expect(!OnboardingSlides.all.contains { $0.kind == .access })
    }

    @Test func aSlideIsIdentifiedByItsScene() {
        #expect(OnboardingSlides.all.map(\.id) == OnboardingSlides.all.map(\.kind))
        #expect(Set(OnboardingSlides.all.map(\.id)).count == OnboardingSlides.all.count)
    }
}
