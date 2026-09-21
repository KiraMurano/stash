import AppKit
import SwiftUI
import Testing
@testable import BufferJournal

@MainActor
struct AccessoryWindowTests {
    /// Потолок — вся полезная высота экрана без зазора сверху и поля снизу.
    @Test func theCapIsTheScreenLessTheGapAndTheMargin() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 876)
        let cap = AccessoryWindow<EmptyView>.heightCap(visibleFrame: screen)

        #expect(cap == 876 - StatusItemAnchor.topGap - StatusItemAnchor.bottomMargin)
    }

    /// На крошечном экране потолок не уходит в ноль и не становится отрицательным.
    @Test func theCapNeverFallsBelowAFloor() {
        let tiny = NSRect(x: 0, y: 0, width: 800, height: 40)
        #expect(AccessoryWindow<EmptyView>.heightCap(visibleFrame: tiny) == 120)
    }

    /// Ради чего всё: окно обновления подгоняется под длину списка. Ширина задана,
    /// высоту называет содержимое, и окно обязано её взять.
    @Test func aWindowThatGrowsWithItsContentTakesItsHeight() {
        let window = AccessoryWindow(
            placement: .center,
            sizing: .fitsContent(width: 400),
            cornerRadius: 20,
            rootView: Color.clear.frame(width: 400, height: 321)
        )

        #expect(window.contentSize == NSSize(width: 400, height: 321))
    }

    /// Длинный список не выталкивает окно за край экрана: высота упирается в потолок,
    /// а прокручивается то, что внутри.
    @Test func aWindowThatGrowsStopsAtTheCap() throws {
        let screen = try #require(NSScreen.main)
        let cap = AccessoryWindow<EmptyView>.heightCap(visibleFrame: screen.visibleFrame)

        let window = AccessoryWindow(
            placement: .center,
            sizing: .fitsContent(width: 400),
            cornerRadius: 20,
            rootView: Color.clear.frame(width: 400, height: cap + 2000)
        )

        #expect(window.contentSize.height == cap)
    }

    /// Как вживую: окно построено, когда релиза ещё нет, список приезжает позже — и окно
    /// обязано под него вырасти, а не остаться той высоты, с какой его собрали.
    @Test func theWindowGrowsWhenTheListArrivesLater() async throws {
        let screen = try #require(NSScreen.main)
        let cap = AccessoryWindow<EmptyView>.heightCap(visibleFrame: screen.visibleFrame)
        let controller = updateController(notes: Self.longNotes)

        let window = AccessoryWindow(
            placement: .center,
            sizing: .fitsContent(width: 400),
            cornerRadius: 20,
            rootView: UpdateView(controller: controller, l10n: L10n(language: .russian), onClose: {})
        )
        let beforeTheList = window.contentSize.height

        await controller.check(manual: true)
        // Пересчёт высоты отложен через Task: дать циклу сойтись.
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(beforeTheList < cap)
        #expect(window.contentSize.height == cap)
    }

    /// Короткий список прокручиваться не должен вовсе: окно ровно под него и подстраивается.
    @Test func aShortListMakesAShortWindow() async throws {
        let screen = try #require(NSScreen.main)
        let cap = AccessoryWindow<EmptyView>.heightCap(visibleFrame: screen.visibleFrame)
        let controller = updateController(notes: (1...5).map { "- Пункт \($0)." }.joined(separator: "\n"))
        await controller.check(manual: true)

        let window = AccessoryWindow(
            placement: .center,
            sizing: .fitsContent(width: 400),
            cornerRadius: 20,
            rootView: UpdateView(controller: controller, l10n: L10n(language: .russian), onClose: {})
        )

        // Шапка 28, футер 36, поля 12/16 и два шага по 10 — это 112; пять строк по 18 с
        // отбивками по 8 — ещё 122.
        #expect(window.contentSize.height == 234)
        #expect(window.contentSize.height < cap)
    }

    /// Окно с заданным размером берёт его как есть.
    @Test func aFixedWindowKeepsTheSizeItWasGiven() {
        let window = AccessoryWindow(
            placement: .center,
            sizing: .fixed(NSSize(width: 640, height: 440)),
            cornerRadius: 24,
            rootView: Color.clear
        )

        #expect(window.contentSize == NSSize(width: 640, height: 440))
    }

    // MARK: Заглушки

    private static let longNotes = (1...40)
        .map { "- Пункт номер \($0), достаточно длинный, чтобы занять строку целиком и перенестись." }
        .joined(separator: "\n")

    private struct Checker: UpdateChecking {
        let release: Release
        func latestRelease() async throws -> Release? { release }
    }

    private struct Downloader: UpdateDownloading {
        func download(_ release: Release, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
            throw UpdateError.network
        }
    }

    private func updateController(notes: String) -> UpdateController {
        let release = Release(
            version: AppVersion(major: 1, minor: 27),
            notes: notes,
            dmgURL: URL(string: "https://example.invalid/Stash-1.27.dmg")!,
            size: 4_404_019
        )
        return UpdateController(
            environment: UpdateEnvironment(
                currentVersion: AppVersion(major: 1, minor: 26),
                requirement: "req",
                bundleURL: URL(fileURLWithPath: "/Applications/Stash.app"),
                isDestinationWritable: true
            ),
            checker: Checker(release: release),
            downloader: Downloader(),
            defaults: UserDefaults(suiteName: "AccessoryWindowTests-\(UUID().uuidString)")!,
            isReady: { true },
            install: { _ in },
            quit: {}
        )
    }
}
