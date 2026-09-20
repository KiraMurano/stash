import Foundation
import Testing
@testable import BufferJournal

struct CodesignTests {
    /// Пустой бандл приложения: Info.plist и пустой исполняемый файл — этого хватает codesign.
    private func makeBundle(marker: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodesignTests-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Stash.app")
        let macos = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
        try Data(marker.utf8).write(to: macos.appendingPathComponent("BufferJournal"))
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleExecutable</key><string>BufferJournal</string>
        <key>CFBundleIdentifier</key><string>local.buffer-journal</string>
        </dict></plist>
        """.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
        return app
    }

    @Test func aSignedBundleSatisfiesItsOwnRequirement() throws {
        let app = try makeBundle(marker: "one")
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }

        try Codesign.sign(app, identifier: "local.buffer-journal")
        let requirement = try Codesign.designatedRequirement(of: app)
        // Ad hoc подписи нечем себя назвать, кроме хеша сборки; сертификат дал бы идентификатор
        // и хеш листа, одинаковые от сборки к сборке.
        #expect(requirement.contains("cdhash"))
        try Codesign.verify(app, requirement: requirement, deep: true)
    }

    @Test func anotherBuildFailsACdhashRequirement() throws {
        // Именно это и ломает ad hoc подпись: требование держит cdhash, а он у каждой сборки свой.
        let first = try makeBundle(marker: "one")
        let second = try makeBundle(marker: "two")
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        try Codesign.sign(first, identifier: "local.buffer-journal")
        try Codesign.sign(second, identifier: "local.buffer-journal")

        let requirement = try Codesign.designatedRequirement(of: first)
        #expect(throws: (any Error).self) {
            try Codesign.verify(second, requirement: requirement, deep: true)
        }
    }

    @Test func theIdentifierAloneIsSatisfiedByBothBuilds() throws {
        let first = try makeBundle(marker: "one")
        let second = try makeBundle(marker: "two")
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        try Codesign.sign(first, identifier: "local.buffer-journal")
        try Codesign.sign(second, identifier: "local.buffer-journal")

        let requirement = #"identifier "local.buffer-journal""#
        try Codesign.verify(first, requirement: requirement, deep: true)
        try Codesign.verify(second, requirement: requirement, deep: true)
    }

    @Test func anUnsignedBundleSatisfiesNothing() throws {
        let app = try makeBundle(marker: "bare")
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }

        #expect(throws: (any Error).self) {
            try Codesign.verify(app, requirement: #"identifier "local.buffer-journal""#, deep: true)
        }
    }

    @Test func aPathWithSpacesIsHandedOverWhole() throws {
        let app = try makeBundle(marker: "spaced")
        let spaced = app.deletingLastPathComponent().appendingPathComponent("Stash Copy.app")
        try FileManager.default.moveItem(at: app, to: spaced)
        defer { try? FileManager.default.removeItem(at: spaced.deletingLastPathComponent()) }

        try Codesign.sign(spaced, identifier: "local.buffer-journal")
        try Codesign.verify(spaced, requirement: #"identifier "local.buffer-journal""#, deep: true)
    }
}
