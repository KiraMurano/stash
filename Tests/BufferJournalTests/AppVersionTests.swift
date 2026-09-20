import Testing
@testable import BufferJournal

struct AppVersionTests {
    @Test func readsAPlainVersion() {
        #expect(AppVersion("1.27") == AppVersion(major: 1, minor: 27))
    }

    @Test func readsATagWithItsLetter() {
        #expect(AppVersion("v1.27") == AppVersion(major: 1, minor: 27))
    }

    @Test func trimsSurroundingSpace() {
        #expect(AppVersion(" v1.27\n") == AppVersion(major: 1, minor: 27))
    }

    @Test func refusesWhatIsNotAVersion() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("1") == nil)
        #expect(AppVersion("1.2.3") == nil)
        #expect(AppVersion("v1.x") == nil)
    }

    @Test func comparesTheMajorFirst() {
        #expect(AppVersion("0.25")! < AppVersion("1.26")!)
        #expect(AppVersion("1.26")! > AppVersion("0.99")!)
    }

    @Test func comparesTheMinorWithinTheMajor() {
        #expect(AppVersion("1.26")! < AppVersion("1.27")!)
        #expect(!(AppVersion("1.27")! < AppVersion("1.27")!))
    }

    @Test func printsItselfBack() {
        #expect(AppVersion("v1.27")!.description == "1.27")
    }
}
