import SwiftUI

/// ЗАКРЕП: the arrow pins the office address; the row rises into a new "Pinned" section. Then two
/// new clips arrive at the top of "Today" and push the older ones out, while the pinned one stays.
struct PinScene: View {
    static let duration = 4.6
    /// The list, with room on its right for the arrow to step away.
    static let size = CGSize(width: 310, height: 234)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var hovered: String?
        var isPinned: Bool
        var arrived: Int
    }

    /// The pin button of the address row: the first of the row's two, counted back from its
    /// trailing edge (rows x 10…260, y 88…146; buttons 26 wide, 4 apart, 8 from the edge).
    static let pinButton = CGPoint(x: 260 - 8 - 2 * 26 - 4 + 13, y: 117)
    static let click = 1.4

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 296, y: 240))
            .to(CGPoint(x: 110, y: 117), at: 0.3, until: 0.8)
            .to(pinButton, at: 0.95, until: 1.3)
            .to(CGPoint(x: 290, y: 172), at: 1.55, until: 1.95),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [click]
    )
    private static let hovered = Track<String?>(nil).set("pin-address", at: 0.62).set(nil, at: 1.62)
    private static let pinned = Track(false).set(true, at: click + 0.04)
    private static let arrived = Track(0).set(1, at: 2.4).set(2, at: 2.9)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            hovered: hovered.value(at: time),
            isPinned: pinned.value(at: time),
            arrived: arrived.value(at: time)
        )
    }

    /// Rows in list order: the pinned section, then "Today" — at most two clips once something is
    /// pinned, so the newest push the oldest out.
    static func layout(_ state: State) -> [String] {
        var today = ["pin-link", "pin-address", "pin-photo"]
        if state.isPinned {
            today.removeAll { $0 == "pin-address" }
        }
        today.insert(contentsOf: ["pin-order", "pin-promo"].suffix(state.arrived), at: 0)
        if state.isPinned {
            today = Array(today.prefix(2))
        }
        return (state.isPinned ? ["header-pinned", "pin-address"] : []) + ["header-today"] + today
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let clips = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })
        let items = Self.layout(state)

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    switch item {
                    case "header-pinned":
                        SectionHeader(title: l10n("Pinned", "Закреплённые"), palette: palette)
                            .transition(.opacity)
                    case "header-today":
                        SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                    default:
                        if let clip = clips[item] {
                            DemoRow(
                                clip: item == "pin-address" ? clip.pinned(state.isPinned) : clip,
                                isHovered: state.hovered == item,
                                palette: palette
                            )
                            .transition(.journalRow)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 270)
            .offset(y: 4)
            .animation(.easeOut(duration: 0.3), value: items)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private var clips: [DemoClip] {
        [
            DemoClips.text("pin-link", Localized(en: "Link to the slides", ru: "Ссылка на презентацию"), l10n, at: 14, 20),
            DemoClips.text("pin-address", Localized(en: "Office address: 12 Main St, entrance 3", ru: "Адрес офиса: Тверская, 12, подъезд 3"), l10n, at: 13, 5),
            DemoClips.image("pin-photo", .sunset, pixelSize: CGSize(width: 900, height: 1200), at: 11, 48),
            DemoClips.text("pin-promo", Localized(en: "Promo code AUTUMN25", ru: "Промокод AUTUMN25"), l10n, at: 14, 31),
            DemoClips.text("pin-order", Localized(en: "Order number 48213", ru: "Номер заказа 48213"), l10n, at: 14, 35),
        ]
    }
}
