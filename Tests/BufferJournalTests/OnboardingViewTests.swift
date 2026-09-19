import Testing
@testable import BufferJournal

@MainActor
struct OnboardingViewTests {
    @Test func voiceOverReadsSlideWordsAsSentences() {
        #expect(OnboardingView.spoken("ПРИВЕТ, ЭТО") == "Привет, это")
        #expect(OnboardingView.spoken("HELLO, THIS IS") == "Hello, this is")
        #expect(OnboardingView.spoken("ЗАКРЕП") == "Закреп")
    }
}
