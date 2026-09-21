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
        window.fitToContent()

        #expect(beforeTheList < cap)
        #expect(window.contentSize.height == cap)
    }

    /// Случай, который дольше всего был сломан: список длиннее окна, но короче экрана. Высоту
    /// такого списка видно, только если мерить на заданной ширине — иначе каждый абзац считается
    /// в одну строку, и окно выходит вдвое ниже нужного.
    @Test func aListThatWrapsIsMeasuredWithItsWrapping() async throws {
        let screen = try #require(NSScreen.main)
        let cap = AccessoryWindow<EmptyView>.heightCap(visibleFrame: screen.visibleFrame)
        let controller = updateController(notes: Self.wrappingNotes)
        await controller.check(manual: true)

        let window = AccessoryWindow(
            placement: .center,
            sizing: .fitsContent(width: 400),
            cornerRadius: 20,
            rootView: UpdateView(controller: controller, l10n: L10n(language: .russian), onClose: {})
        )

        // Сколько вышло бы, посчитай мы каждый блок в одну строку, — ровно та ошибка, из-за
        // которой окно было вдвое ниже нужного. Шапка, футер, поля и два шага дают 112;
        // строка 13 pt при межстрочном 1,4 — 18, отбивка между блоками — 8.
        let blocks = CGFloat(ReleaseNotes.parse(Self.wrappingNotes).count)
        let ifNothingWrapped = 112 + blocks * 18 + (blocks - 1) * 8

        #expect(window.contentSize.height > ifNothingWrapped)
        #expect(window.contentSize.height < cap)
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

    /// Настоящие заметки первого релиза Stash: семь блоков, почти каждый в две строки на 400 pt.
    private static let wrappingNotes = """
        First public release of Stash — a minimal clipboard history for macOS.

        - `Option+V` opens the journal: clips on the left, the selected clip in full on the right
        - Text and images, search, keyboard navigation, paste on selection
        - Keeps up to 20 clips for 24 hours, stored locally
        - English and Russian interface, light and dark themes
        - Universal build (Apple silicon and Intel), macOS 13+

        **Install:** open the DMG and drag Stash.app onto Applications. The app is not notarized, \
        so macOS blocks the first launch: click Done, then open System Settings.
        """

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
