import Foundation
import Testing
@testable import BufferJournal

struct UpdateInstallerTests {
    // MARK: Окружение

    @Test func pathsGoIntoTheEnvironmentWhole() {
        let environment = UpdateInstaller.environment(
            dmg: URL(fileURLWithPath: "/tmp/my images/Stash 1.27.dmg"),
            destination: URL(fileURLWithPath: "/Applications/My Apps/Stash.app"),
            requirement: #"identifier "local.buffer-journal""#,
            pid: 4321,
            relaunch: true
        )

        #expect(environment["STASH_DMG"] == "/tmp/my images/Stash 1.27.dmg")
        #expect(environment["STASH_DEST"] == "/Applications/My Apps/Stash.app")
        #expect(environment["STASH_APP_NAME"] == "Stash.app")
        #expect(environment["STASH_REQUIREMENT"] == #"identifier "local.buffer-journal""#)
        #expect(environment["STASH_PID"] == "4321")
        #expect(environment["STASH_RELAUNCH"] == "1")
    }

    @Test func theMarkerLivesBesideTheHistory() {
        #expect(UpdateFailureMarker.url.lastPathComponent == "update-failure.txt")
        #expect(UpdateFailureMarker.url.deletingLastPathComponent().lastPathComponent == "BufferJournal")
    }

    // MARK: Скрипт целиком

    /// Пустой бандл с опознавательным файлом внутри.
    private func makeBundle(at url: URL, marker: String) throws {
        let macos = url.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
        try Data(marker.utf8).write(to: macos.appendingPathComponent("BufferJournal"))
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleExecutable</key><string>BufferJournal</string>
        <key>CFBundleIdentifier</key><string>local.buffer-journal</string>
        </dict></plist>
        """.write(to: url.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
    }

    private func shell(_ tool: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        _ = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Гоняет скрипт как есть и ждёт его конца.
    private func runScript(_ environment: [String: String]) throws -> Int32 {
        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("stash-update-\(UUID().uuidString).sh")
        try UpdateInstaller.script.write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Проходит весь путь: образ → монтирование → копия → подмена.
    /// Требование здесь — `identifier`, а не хеш сертификата: обе стороны подписаны ad hoc,
    /// и их cdhash не совпадает по определению. Проверяется ход скрипта, не стойкость требования.
    @Test func theScriptPutsTheNewVersionInPlace() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpdateInstallerTests-\(UUID().uuidString)")
        let stagingFolder = root.appendingPathComponent("image")
        let installed = root.appendingPathComponent("Applications/Stash.app")
        // Скрипт подчищает за собой каталог образа целиком, поэтому образ лежит в своём.
        let downloads = root.appendingPathComponent("download")
        try FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try makeBundle(at: installed, marker: "old")
        let fresh = stagingFolder.appendingPathComponent("Stash.app")
        try makeBundle(at: fresh, marker: "new")
        try Codesign.sign(installed, identifier: "local.buffer-journal")
        try Codesign.sign(fresh, identifier: "local.buffer-journal")

        let dmg = downloads.appendingPathComponent("Stash-1.27.dmg")
        #expect(try shell("/usr/bin/hdiutil", [
            "create", "-srcfolder", stagingFolder.path, "-volname", "Stash 1.27",
            "-ov", "-quiet", "-format", "UDZO", dmg.path,
        ]) == 0)
        #expect(try shell("/usr/bin/codesign", [
            "--force", "--sign", "-", "--identifier", "local.buffer-journal", dmg.path,
        ]) == 0)

        let status = try runScript(UpdateInstaller.environment(
            dmg: dmg,
            destination: installed,
            requirement: #"identifier "local.buffer-journal""#,
            pid: 1,                  // существующий и точно не наш процесс: launchd
            relaunch: false
        ))

        #expect(status == 0)
        let executable = installed.appendingPathComponent("Contents/MacOS/BufferJournal")
        #expect(String(decoding: try Data(contentsOf: executable), as: UTF8.self) == "new")
        // Ни промежуточных копий, ни резервной: каталог чист.
        let left = try FileManager.default.contentsOfDirectory(atPath: installed.deletingLastPathComponent().path)
        #expect(left == ["Stash.app"])
    }

    /// Подпись не сошлась: установленное приложение остаётся на месте, остаётся и маркер.
    @Test func aWrongRequirementChangesNothing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpdateInstallerTests-\(UUID().uuidString)")
        let stagingFolder = root.appendingPathComponent("image")
        let installed = root.appendingPathComponent("Applications/Stash.app")
        let downloads = root.appendingPathComponent("download")
        try FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try makeBundle(at: installed, marker: "old")
        try makeBundle(at: stagingFolder.appendingPathComponent("Stash.app"), marker: "new")
        try Codesign.sign(stagingFolder.appendingPathComponent("Stash.app"), identifier: "local.buffer-journal")

        let dmg = downloads.appendingPathComponent("Stash-1.27.dmg")
        _ = try shell("/usr/bin/hdiutil", [
            "create", "-srcfolder", stagingFolder.path, "-volname", "Stash 1.27",
            "-ov", "-quiet", "-format", "UDZO", dmg.path,
        ])
        _ = try shell("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", "local.buffer-journal", dmg.path])

        let marker = root.appendingPathComponent("update-failure.txt")
        var environment = UpdateInstaller.environment(
            dmg: dmg,
            destination: installed,
            requirement: #"identifier "com.someone.else""#,
            pid: 1,
            relaunch: false
        )
        environment["STASH_MARKER"] = marker.path

        #expect(try runScript(environment) != 0)
        let executable = installed.appendingPathComponent("Contents/MacOS/BufferJournal")
        #expect(String(decoding: try Data(contentsOf: executable), as: UTF8.self) == "old")
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }
}
