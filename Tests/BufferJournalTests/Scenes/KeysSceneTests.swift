import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct KeysSceneTests {
    @Test func keysEndWithTheThirdClipBehindTheTypedWordAndTheJournalGone() {
        let end = KeysScene.state(at: .end(of: KeysScene.duration))
        #expect(end.typed == KeysScene.letters)
        #expect(end.selectedRow == 2)
        #expect(end.pasted == 1)
        #expect(end.journal == 0)
        #expect(!end.downPressed && !end.returnPressed)

        // The letters go to the document while the journal is open.
        let typing = KeysScene.state(at: SceneTime(t: 0.5, rewind: 0))
        #expect(typing.typed == 1)
        #expect(typing.journal == 1)

        // One ↓ moves the selection by one row, and nothing is pasted yet.
        let afterFirstDown = KeysScene.state(at: SceneTime(t: 1.8, rewind: 0))
        #expect(afterFirstDown.selectedRow == 1)
        #expect(afterFirstDown.pasted == 0)
        #expect(KeysScene.state(at: SceneTime(t: 1.65, rewind: 0)).downPressed)
        #expect(KeysScene.state(at: SceneTime(t: 2.65, rewind: 0)).returnPressed)
    }

    @Test func theSceneTypesThreeLettersInBothLanguages() {
        #expect(KeysScene.word.ru == "нап")
        #expect(KeysScene.word.en == "typ")
        #expect(KeysScene.word.ru.count == KeysScene.letters)
        #expect(KeysScene.word.en.count == KeysScene.letters)
    }
}
