import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct ImagesSceneTests {
    @Test func imagesEndsInPreviewWithTheImagesFilter() {
        let end = ImagesScene.state(at: .end(of: ImagesScene.duration))
        #expect(end.filter == 2)
        #expect(end.preview == 1)
        #expect(end.cursor.tip == ImagesScene.picture)
    }
}
