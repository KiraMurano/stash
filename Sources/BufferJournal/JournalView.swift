import AppKit
import Combine
import SwiftUI

/// Split journal: a denser frosted list with orange accents on the left, the selected clip
/// in full on a lighter frosted pane on the right (concept 1.3.2.2, `.concepts/2026-09-18-journal-layout.html`).
struct JournalView: View {
    enum Layout {
        static let width: CGFloat = 640
        static let height: CGFloat = 440
        static let minWidth: CGFloat = 560
        static let minHeight: CGFloat = 360
        static let cornerRadius: CGFloat = 24
        static let sidebarWidth: CGFloat = 290
        static let sidebarMinWidth: CGFloat = 240
        static let sidebarMaxWidth: CGFloat = 440
        static let detailMinWidth: CGFloat = 300
        static let rowHeight: CGFloat = 58
        /// Transparent strip on the right and bottom of the window for the resize grip.
        static let gripMargin: CGFloat = 4
    }

    private enum EntryFilter: CaseIterable, Identifiable {
        case all
        case text
        case media
        case files

        var id: Self { self }

        func title(_ l10n: L10n) -> String {
            switch self {
            case .all: l10n("All", "Все")
            case .text: l10n("Text", "Текст")
            case .media: l10n("Images", "Картинки")
            case .files: l10n("Files", "Файлы")
            }
        }
    }

    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var access: AccessGate
    @ObservedObject var onboarding: OnboardingController
    /// Opening and closing: the panel grows into place and shrinks back.
    @ObservedObject var presentation: PanelPresentation
    /// The journal's keys, taken as hotkeys while it is open: the panel itself never takes the keyboard.
    let keyEvents: PassthroughSubject<JournalKey, Never>
    /// Returns false when nothing was pasted.
    let onPaste: (ClipboardEntry) -> Bool
    let onCopy: (ClipboardEntry) -> Void
    let onEditText: (ClipboardEntry) -> Void
    let onPreviewImage: (ClipboardEntry) -> Void
    let onOpenAccessSettings: () -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedID: ClipboardEntry.ID?
    @State private var selectedFilter: EntryFilter = .all
    @State private var isClearConfirmationShown = false
    @State private var entryPendingDeletion: ClipboardEntry?
    @State private var toastMessage: String?
    @State private var toastToken = UUID()
    @State private var isListScrolled = false
    @State private var detailEdges = ScrollEdges()
    @State private var draggedPinnedID: ClipboardEntry.ID?
    @State private var dragStartIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var keyboardScrollTarget: KeyboardScrollTarget?
    @State private var sidebarDragStartWidth: CGFloat?
    @AppStorage("SidebarWidth") private var storedSidebarWidth: Double = Double(Layout.sidebarWidth)

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: settings.themeMode.usesSolidAccents)
    }

    private var l10n: L10n {
        settings.l10n
    }

    private var filteredEntries: [ClipboardEntry] {
        switch selectedFilter {
        case .all: store.entries
        case .text: store.entries.filter(\.isText)
        case .media: store.entries.filter(\.isImage)
        case .files: store.entries.filter(\.isFile)
        }
    }

    /// Entries in the order the list shows them (pinned first, then by day), for arrow navigation.
    private var orderedEntries: [ClipboardEntry] {
        sections.flatMap(\.entries)
    }

    /// The explicit selection when it is still visible, otherwise the first clip of the filter.
    private var selectedEntry: ClipboardEntry? {
        filteredEntries.first { $0.id == selectedID } ?? orderedEntries.first
    }

    var body: some View {
        ZStack {
            NativeGlassEffectView(style: .regular, cornerRadius: Layout.cornerRadius)

            journal

            // Dialogs belong to the journal; the access slide over it never shows one left over.
            if access.isGranted, isClearConfirmationShown || entryPendingDeletion != nil {
                ZStack {
                    palette.dialogBackdrop
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isClearConfirmationShown = false
                            entryPendingDeletion = nil
                        }

                    DeleteConfirmationOverlay(
                        title: isClearConfirmationShown ? l10n("Clear history?", "Очистить историю?") : l10n("Delete clip?", "Удалить клип?"),
                        message: isClearConfirmationShown
                            ? l10n("Unpinned clips will be removed. Pinned clips stay saved.", "Незакреплённые клипы будут удалены. Закреплённые останутся.")
                            : l10n("This clip will be removed.", "Этот клип будет удалён."),
                        actionTitle: isClearConfirmationShown ? l10n("Clear", "Очистить") : l10n("Delete", "Удалить"),
                        onCancel: {
                            isClearConfirmationShown = false
                            entryPendingDeletion = nil
                        },
                        onConfirm: {
                            if isClearConfirmationShown {
                                store.clear()
                                isClearConfirmationShown = false
                            } else if let entryPendingDeletion {
                                store.remove(entryPendingDeletion)
                                self.entryPendingDeletion = nil
                            }
                        }
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(20)
            }

            if let toastMessage {
                ToastOverlay(message: toastMessage)
                    .padding(.bottom, 56)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(30)
            }

            // The access screen, and only it: the tour has a window of its own now, and this
            // screen is what stands in for the journal while Stash may not paste.
            if onboarding.isPresented, onboarding.isAccessOnly {
                OnboardingView(
                    controller: onboarding,
                    access: access,
                    l10n: l10n,
                    onOpenSettings: onOpenAccessSettings,
                    onClosePanel: onClose
                )
                .transition(.opacity)
                .zIndex(40)
            }
        }
        .frame(minWidth: Layout.minWidth, idealWidth: Layout.width, minHeight: Layout.minHeight, idealHeight: Layout.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        // The grip hugs the rounded corner from outside: anchored to the panel's corner square
        // and nudged out so its strokes sit just past the curve, in a thin transparent margin.
        .overlay(alignment: .bottomTrailing) {
            WindowResizeGrip(palette: palette, cornerRadius: Layout.cornerRadius, margin: Layout.gripMargin)
                .offset(x: Layout.gripMargin, y: Layout.gripMargin)
        }
        .padding(.trailing, Layout.gripMargin)
        .padding(.bottom, Layout.gripMargin)
        .scaleEffect(presentation.isOpen ? 1 : PanelPresentation.closedScale)
        .animation(.easeOut(duration: 0.16), value: isClearConfirmationShown)
        .animation(.easeOut(duration: 0.16), value: entryPendingDeletion)
        .animation(.easeOut(duration: 0.2), value: onboarding.isPresented)
        .preferredColorScheme(settings.themeMode.colorScheme)
        .environment(\.l10n, l10n)
        .environment(\.solidAccents, settings.themeMode.usesSolidAccents)
        .onReceive(keyEvents) { handleKey($0) }
    }

    /// The split journal: clips on the left, the selected clip in full on the right.
    private var journal: some View {
        GeometryReader { geometry in
            let width = sidebarWidth(in: geometry.size.width)

            HStack(spacing: 0) {
                sidebar
                    .frame(width: width)
                    .background(palette.sidebarTint)
                    .overlay(alignment: .trailing) {
                        palette.separator.frame(width: 1)
                    }
                    .overlay(alignment: .trailing) {
                        SidebarResizeHandle(
                            palette: palette,
                            onChanged: { translation in
                                let start = sidebarDragStartWidth ?? width
                                sidebarDragStartWidth = start
                                storedSidebarWidth = Double(clampedSidebarWidth(start + translation, in: geometry.size.width))
                            },
                            onEnded: { sidebarDragStartWidth = nil }
                        )
                        // Hit area spans 4 pt left of the divider to 10 pt right of it, so the
                        // border and the grab mark light up and drag as one.
                        .offset(x: 10)
                    }
                    .zIndex(1)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.detailTint)
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Logo.iconFrame, height: Logo.iconFrame)
                    .overlay(WindowDragHandle())

                Text("Stash")
                    .font(.system(size: Logo.fontSize, weight: .heavy))
                    .foregroundStyle(palette.textPrimary)
                    // Center on the capital letters, not on the line box, so "S" lines up with the icon.
                    .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - Logo.capHeight / 2 }
                    .overlay(WindowDragHandle())

                Spacer()

                Text("\(store.entries.count)/20")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.textTertiary)
                    .overlay(WindowDragHandle())
                    .padding(.trailing, 6)

                GlassIconButton(
                    systemName: "trash",
                    isDestructive: true,
                    help: l10n("Clear history", "Очистить историю"),
                    action: { isClearConfirmationShown = true }
                )
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(WindowDragHandle())

            TypeSegmentedControl(
                titles: EntryFilter.allCases.map { $0.title(l10n) },
                selectedIndex: EntryFilter.allCases.firstIndex(of: selectedFilter) ?? 0,
                palette: palette,
                onSelect: { index in
                    withAnimation(.easeOut(duration: 0.22)) {
                        selectedFilter = EntryFilter.allCases[index]
                    }
                }
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .background(WindowDragHandle())
            .overlay(alignment: .bottom) {
                // Shadow under the header once the list scrolls beneath it.
                EdgeShadow(palette: palette, edge: .top)
                    .offset(y: EdgeShadow.height)
                    .opacity(isListScrolled ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: isListScrolled)
                    .allowsHitTesting(false)
            }
            .zIndex(1)

            if filteredEntries.isEmpty {
                Text(emptyStateMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WindowDragHandle())
            } else {
                entryList
            }
        }
    }

    private static let listBottomID = "list-bottom"

    /// Title sized by eye against the icon tile (the system draws it on ~71% of the frame);
    /// the cap height is still used to centre "Stash" on its capitals.
    private enum Logo {
        static let iconFrame: CGFloat = 32
        static let fontSize: CGFloat = 28
        static let capHeight = NSFont.systemFont(ofSize: fontSize, weight: .heavy).capHeight
    }

    /// A plain scroll view with a stack of fixed-height rows. History holds at most 20 clips, so
    /// nothing needs to be lazy; AppKit's List re-measured and re-used cells, which made scrolling
    /// jumpy and inserts snap.
    private var entryList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sections, id: \.title) { section in
                        SectionHeader(title: section.title, palette: palette)
                            .id(section.title)

                        ForEach(section.entries) { entry in
                            row(entry, pinned: section.isPinned ? section.entries : nil)
                                .id(entry.id)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: -10)),
                                        removal: .opacity.combined(with: .scale(scale: 0.96))
                                    )
                                )
                        }
                    }

                    Color.clear
                        .frame(height: 8)
                        .id(Self.listBottomID)
                }
                // 10 pt keeps the selection bar (drawn 6 pt left of a row) off the pane's edge.
                .padding(.horizontal, 10)
                .background(ScrollBarAppearanceSetter(colorScheme: colorScheme))
            }
            .background(ScrollOffsetObserver { isListScrolled = $0.isScrolled })
            // New clips arrive from the pasteboard monitor outside any transaction: animate inserts,
            // removals and reorders here so rows slide apart and the new one fades in.
            .animation(.easeOut(duration: 0.3), value: store.entries.map(\.id))
            .onChange(of: keyboardScrollTarget) { target in
                guard let target else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    switch target {
                    case let .entry(id): proxy.scrollTo(id)
                    case .top: if let first = sections.first { proxy.scrollTo(first.title, anchor: .top) }
                    case .bottom: proxy.scrollTo(Self.listBottomID, anchor: .bottom)
                    }
                }
                keyboardScrollTarget = nil
            }
        }
    }

    private func row(_ entry: ClipboardEntry, pinned: [ClipboardEntry]?) -> some View {
        EntryRow(
            entry: entry,
            thumbnail: store.thumbnail(for: entry),
            fileIcon: store.fileIcon(for: entry),
            title: rowTitle(entry),
            subtitle: rowSubtitle(entry),
            isSelected: entry.id == selectedEntry?.id,
            isCurrent: store.currentClipboardFingerprint == entry.fingerprint,
            palette: palette,
            onExpand: expandAction(for: entry),
            onTogglePin: { togglePin(entry) },
            onDelete: { entryPendingDeletion = entry }
        )
        .offset(y: draggedPinnedID == entry.id ? draggedRowOffset(in: pinned ?? []) : 0)
        .shadow(color: draggedPinnedID == entry.id ? palette.shadow(0.18) : .clear, radius: 10, y: 4)
        .zIndex(draggedPinnedID == entry.id ? 1 : 0)
        .gesture(pinnedDragGesture(for: entry, in: pinned ?? []), including: pinned == nil ? .subviews : .all)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedID = entry.id
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded { paste(entry) })
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let entry = selectedEntry {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(entry.isFile ? entry.title(l10n) : kindTitle(entry))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .overlay(WindowDragHandle())

                    Text("· \(timeTitle(entry.createdAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                        .overlay(WindowDragHandle())

                    if store.currentClipboardFingerprint == entry.fingerprint {
                        Text(l10n("in clipboard", "в буфере"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.onAccent)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(palette.accentFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(WindowDragHandle())
                    }

                    Spacer()

                    GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: onClose)
                }
                .padding(.leading, 16)
                .padding(.trailing, 10)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .background(WindowDragHandle())
                .overlay(alignment: .bottom) {
                    EdgeShadow(palette: palette, edge: .top)
                        .offset(y: EdgeShadow.height)
                        .opacity(entry.isText && detailEdges.isScrolled ? 1 : 0)
                }
                .zIndex(1)

                stage(for: entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Text scrolls edge to edge under the header and footer; its insets are inside.
                    .padding(.horizontal, entry.isText ? 0 : 16)
                    .padding(.vertical, entry.isText ? 0 : 12)

                VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(l10n("Size", "Размер"))
                        .foregroundStyle(palette.textTertiary)
                    Text(metaTitle(entry))
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)

                actionBar(for: entry)
                }
                .overlay(alignment: .top) {
                    EdgeShadow(palette: palette, edge: .bottom)
                        .offset(y: -EdgeShadow.height)
                        .opacity(entry.isText && detailEdges.hasMoreBelow ? 1 : 0)
                }
                .zIndex(1)
            }
            .animation(.easeOut(duration: 0.15), value: detailEdges)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(palette.textTertiary)
                Text(l10n("Nothing copied yet", "Пока ничего не скопировано"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WindowDragHandle())
            .overlay(alignment: .topTrailing) {
                GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: onClose)
                    .padding(10)
            }
        }
    }

    @ViewBuilder
    private func stage(for entry: ClipboardEntry) -> some View {
        switch entry.payload {
        case let .text(text):
            ScrollView {
                // One Text per line in a lazy stack: a long clip no longer lays out as a single
                // huge block, so it scrolls as smoothly as the list. Selection works within a line.
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(text.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 13))
                            .lineSpacing(3)
                            .foregroundStyle(palette.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                // Insets live inside the scroll view so the scroller gets its own lane on the right.
                .padding(.leading, 16)
                .padding(.trailing, 22)
                .padding(.vertical, 10)
                .background(ScrollBarAppearanceSetter(colorScheme: colorScheme))
            }
            .background(ScrollOffsetObserver { detailEdges = $0 })
            // A new clip starts at the top instead of keeping the previous clip's scroll position.
            .id(entry.id)

        case .image:
            if let image = store.image(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: palette.shadow(0.18), radius: 10, y: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { onPreviewImage(entry) }
                    .help(l10n("Open in Preview", "Открыть в Просмотре"))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.placeholderBackground)
            }

        case .file:
            VStack(spacing: 10) {
                Group {
                    if let icon = store.fileIcon(for: entry) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "doc")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(width: 72, height: 72)

                Text(entry.title(l10n))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func actionBar(for entry: ClipboardEntry) -> some View {
        HStack(spacing: 6) {
            if entry.isText {
                GlassIconButton(systemName: "pencil", help: l10n("Edit text", "Редактировать"), action: { onEditText(entry) })
            }

            if entry.isImage {
                GlassIconButton(systemName: "arrow.up.left.and.arrow.down.right", help: l10n("Open in Preview", "Открыть в Просмотре"), action: { onPreviewImage(entry) })
            }

            GlassIconButton(
                systemName: entry.isPinned ? "pin.fill" : "pin",
                tint: entry.isPinned ? palette.accentText : nil,
                help: entry.isPinned ? l10n("Unpin clip", "Открепить") : l10n("Pin clip", "Закрепить"),
                action: { togglePin(entry) }
            )

            GlassIconButton(
                systemName: "trash",
                isDestructive: true,
                help: l10n("Delete clip", "Удалить"),
                action: { entryPendingDeletion = entry }
            )

            Spacer()

            GlassIconButton(
                systemName: "doc.on.doc",
                help: l10n("Copy to clipboard", "Скопировать в буфер"),
                action: { copy(entry) }
            )

            Button {
                paste(entry)
            } label: {
                HStack(spacing: 6) {
                    Text(l10n("Paste", "Вставить"))
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 28)
            }
            .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            palette.separator.frame(height: 1)
        }
    }

    // MARK: Data

    private enum KeyboardScrollTarget: Equatable {
        case entry(ClipboardEntry.ID)
        case top
        case bottom
    }

    private struct EntrySection {
        let title: String
        let entries: [ClipboardEntry]
        let isPinned: Bool
    }

    private var sections: [EntrySection] {
        let calendar = Calendar.current
        var result: [EntrySection] = []
        let pinned = filteredEntries.filter(\.isPinned)
        if !pinned.isEmpty {
            result.append(EntrySection(title: l10n("Pinned", "Закреплённые"), entries: pinned, isPinned: true))
        }

        let rest = filteredEntries.filter { !$0.isPinned }
        let today = rest.filter { calendar.isDateInToday($0.createdAt) }
        let yesterday = rest.filter { calendar.isDateInYesterday($0.createdAt) }
        let earlier = rest.filter { !calendar.isDateInToday($0.createdAt) && !calendar.isDateInYesterday($0.createdAt) }
        for (title, entries) in [(l10n("Today", "Сегодня"), today), (l10n("Yesterday", "Вчера"), yesterday), (l10n("Earlier", "Раньше"), earlier)] where !entries.isEmpty {
            result.append(EntrySection(title: title, entries: entries, isPinned: false))
        }
        return result
    }

    // MARK: Pinned drag

    /// Rows have one fixed height, so the drop slot is the start index plus whole rows dragged.
    private func pinnedDragGesture(for entry: ClipboardEntry, in pinned: [ClipboardEntry]) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if draggedPinnedID == nil {
                    draggedPinnedID = entry.id
                    dragStartIndex = pinned.firstIndex { $0.id == entry.id } ?? 0
                }
                guard draggedPinnedID == entry.id else { return }
                dragTranslation = value.translation.height

                guard let current = pinned.firstIndex(where: { $0.id == entry.id }) else { return }
                let slots = Int((dragTranslation / Layout.rowHeight).rounded())
                let target = min(max(dragStartIndex + slots, 0), pinned.count - 1)
                guard target != current else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    store.movePinnedEntry(sourceID: entry.id, to: pinned[target].id, afterTarget: target > current)
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    draggedPinnedID = nil
                    dragTranslation = 0
                }
            }
    }

    /// The dragged row follows the pointer; once it has moved slots in the data, the layout already
    /// shifted it, so subtract those whole rows.
    private func draggedRowOffset(in pinned: [ClipboardEntry]) -> CGFloat {
        guard let id = draggedPinnedID, let current = pinned.firstIndex(where: { $0.id == id }) else { return 0 }
        return dragTranslation - CGFloat(current - dragStartIndex) * Layout.rowHeight
    }

    private func kindTitle(_ entry: ClipboardEntry) -> String {
        ClipLabels.kindTitle(entry, l10n)
    }

    private func rowTitle(_ entry: ClipboardEntry) -> String {
        ClipLabels.rowTitle(entry, l10n)
    }

    private func rowSubtitle(_ entry: ClipboardEntry) -> String {
        ClipLabels.rowSubtitle(entry, pixelSize: store.pixelSize(for: entry), l10n)
    }

    private func sidebarWidth(in totalWidth: CGFloat) -> CGFloat {
        clampedSidebarWidth(CGFloat(storedSidebarWidth), in: totalWidth)
    }

    private func clampedSidebarWidth(_ width: CGFloat, in totalWidth: CGFloat) -> CGFloat {
        let upper = max(Layout.sidebarMinWidth, min(Layout.sidebarMaxWidth, totalWidth - Layout.detailMinWidth))
        return min(max(width, Layout.sidebarMinWidth), upper)
    }

    private func metaTitle(_ entry: ClipboardEntry) -> String {
        switch entry.payload {
        case .text, .file:
            return entry.subtitle(l10n)
        case .image:
            var parts: [String] = []
            if let size = pixelSize(of: entry) {
                parts.append(size)
            }
            if
                let url = store.imageURL(for: entry),
                let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber
            {
                parts.append("PNG")
                parts.append(ByteCountFormatter.string(fromByteCount: bytes.int64Value, countStyle: .file))
            }
            return parts.joined(separator: " · ")
        }
    }

    private func pixelSize(of entry: ClipboardEntry) -> String? {
        store.pixelSize(for: entry).map(ClipLabels.pixelSizeTitle)
    }

    private func timeTitle(_ date: Date) -> String {
        ClipLabels.timeTitle(date, l10n)
    }

    private var emptyStateMessage: String {
        if store.entries.isEmpty {
            return l10n("No saved clips", "Нет сохранённых клипов")
        }

        switch selectedFilter {
        case .all: return l10n("No saved clips", "Нет сохранённых клипов")
        case .text: return l10n("No text", "Нет текста")
        case .media: return l10n("No images", "Нет картинок")
        case .files: return l10n("No files", "Нет файлов")
        }
    }

    /// Keys arrive as hotkeys while the panel is open (see `JournalKeys`).
    private func handleKey(_ key: JournalKey) {
        // Nothing is registered while the tutorial covers the journal, and a key that slips
        // through a mode change is not the journal's to act on either.
        guard !onboarding.isPresented else { return }

        let action = JournalKeyAction.resolve(
            key,
            dialogShown: isClearConfirmationShown || entryPendingDeletion != nil,
            hasSelection: selectedEntry != nil
        )

        switch action {
        case .moveUp, .moveDown:
            let entries = orderedEntries
            guard !entries.isEmpty else { return }
            let current = entries.firstIndex { $0.id == selectedEntry?.id } ?? 0
            let next = action == .moveDown ? min(current + 1, entries.count - 1) : max(current - 1, 0)
            selectedID = entries[next].id
            // At the ends scroll to the header / bottom inset so the row keeps its margin.
            keyboardScrollTarget = next == 0 ? .top : (next == entries.count - 1 ? .bottom : .entry(entries[next].id))
        case .paste:
            if let entry = selectedEntry {
                paste(entry)
            }
        case .closeDialog:
            isClearConfirmationShown = false
            entryPendingDeletion = nil
        case .closePanel:
            onClose()
        case .ignore:
            break
        }
    }

    // MARK: Actions

    private func togglePin(_ entry: ClipboardEntry) {
        if !store.togglePin(entry) {
            showToast(l10n("Up to 10 pinned clips", "Максимум 10 закрепов"))
        }
    }

    /// Images open in Preview, files in their default app; text is already shown in full on the right.
    private func expandAction(for entry: ClipboardEntry) -> (() -> Void)? {
        switch entry.payload {
        case .text:
            return nil
        case .image:
            return { onPreviewImage(entry) }
        case .file:
            guard let url = store.fileURL(for: entry) else { return nil }
            return { NSWorkspace.shared.open(url) }
        }
    }

    private func paste(_ entry: ClipboardEntry) {
        selectedID = entry.id
        guard onPaste(entry) else { return }
        if !settings.closeAfterSelection {
            showToast(l10n("Pasted", "Вставлено"))
        }
    }

    private func copy(_ entry: ClipboardEntry) {
        onCopy(entry)
        if !settings.closeAfterSelection {
            showToast(l10n("Copied", "Скопировано"))
        }
    }

    private func showToast(_ message: String) {
        let token = UUID()
        toastToken = token
        toastMessage = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard toastToken == token else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Window chrome

/// Invisible 8 pt strip over the divider: resize cursor on hover, drag changes the list width.
private struct SidebarResizeHandle: View {
    let palette: ThemePalette
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        Color.clear
            .frame(width: 14)
            .frame(maxHeight: .infinity)
            .overlay {
                // Grab mark on the divider; turns orange while hovered or dragged.
                Capsule()
                    .fill(isHovered || isDragging ? ThemePalette.orange : palette.iconOpacity(0.22))
                    .frame(width: 4, height: 32)
                    // Just right of the 1 pt divider line, with a small gap; floats over the preview.
                    .offset(x: 2)
                    .animation(.easeOut(duration: 0.12), value: isHovered || isDragging)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                guard hovering != isHovered else { return }
                isHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged {
                        isDragging = true
                        onChanged($0.translation.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEnded()
                    }
            )
    }
}

/// Bottom-right grip: two diagonal strokes over an AppKit view that resizes the borderless panel,
/// keeping its top-left corner in place.
private struct WindowResizeGrip: View {
    let palette: ThemePalette
    let cornerRadius: CGFloat
    let margin: CGFloat

    @State private var isHovered = false

    private static let size: CGFloat = 30
    /// Dot centre sits 4.5 pt outside the edge: half the 6 pt dot plus a 1.5 pt gap.
    private static let gap: CGFloat = 4.5

    var body: some View {
        Canvas { context, size in
            // A dot on the corner's diagonal, just outside the rounded edge.
            // The panel corner sits `margin` in from the canvas's bottom-right.
            let corner = CGPoint(x: size.width - margin, y: size.height - margin)
            let center = CGPoint(x: corner.x - cornerRadius, y: corner.y - cornerRadius)
            let distance = (cornerRadius + Self.gap) / 2.squareRoot()
            let dot = CGPoint(x: center.x + distance, y: center.y + distance)
            let diameter: CGFloat = 6
            context.fill(
                Path(ellipseIn: CGRect(x: dot.x - diameter / 2, y: dot.y - diameter / 2, width: diameter, height: diameter)),
                with: .color(isHovered ? ThemePalette.orange : palette.iconOpacity(0.22))
            )
        }
        .frame(width: Self.size, height: Self.size)
        // Near-transparent fill so the whole square takes clicks in the transparent margin.
        .background(Color.black.opacity(0.001))
        .background(WindowResizeArea())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct WindowResizeArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        GripView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class GripView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }

        override func resetCursorRects() {
            if #available(macOS 15.0, *) {
                addCursorRect(bounds, cursor: .frameResize(position: .bottomRight, directions: .all))
            } else {
                addCursorRect(bounds, cursor: .crosshair)
            }
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            let startMouse = NSEvent.mouseLocation
            let startFrame = window.frame

            while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type != .leftMouseUp {
                let mouse = NSEvent.mouseLocation
                let width = max(startFrame.width + mouse.x - startMouse.x, window.minSize.width)
                let height = max(startFrame.height - (mouse.y - startMouse.y), window.minSize.height)
                window.setFrame(
                    NSRect(x: startFrame.minX, y: startFrame.maxY - height, width: width, height: height),
                    display: true
                )
            }
        }
    }
}

/// Reports whether the enclosing scroll view has scrolled away from the top. SwiftUI geometry
/// preferences inside a macOS ScrollView do not update while scrolling, so watch the clip view.
/// Soft shadow cast by a header (`.top`, falls downward) or footer (`.bottom`, rises upward)
/// over content scrolling beneath it.
private struct EdgeShadow: View {
    static let height: CGFloat = 20

    let palette: ThemePalette
    let edge: VerticalEdge

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: palette.shadow(0.08), location: 0),
                .init(color: palette.shadow(0.03), location: 0.45),
                .init(color: palette.shadow(0), location: 1)
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: Self.height)
        .allowsHitTesting(false)
    }
}

struct ScrollEdges: Equatable {
    /// Content is scrolled away from the top.
    var isScrolled = false
    /// More content lies below the visible area.
    var hasMoreBelow = false
}

private struct ScrollOffsetObserver: NSViewRepresentable {
    let onChange: (ScrollEdges) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onChange = onChange
    }

    @MainActor
    final class Coordinator {
        var onChange: (ScrollEdges) -> Void
        private weak var scrollView: NSScrollView?
        private var observers: [NSObjectProtocol] = []
        private var lastValue = ScrollEdges()

        init(onChange: @escaping (ScrollEdges) -> Void) {
            self.onChange = onChange
        }

        func attach(from view: NSView, attempt: Int = 0) {
            guard scrollView == nil else { return }
            guard let scrollView = Self.findScrollView(near: view) else {
                // Frames are still zero right after creation; try again once SwiftUI has laid out.
                if attempt < 20 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak view] in
                        guard let view else { return }
                        self?.attach(from: view, attempt: attempt + 1)
                    }
                }
                return
            }
            self.scrollView = scrollView
            let clipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true
            clipView.postsFrameChangedNotifications = true
            scrollView.documentView?.postsFrameChangedNotifications = true
            // Scrolling moves the clip view's bounds; resizing the panel or the content changes frames.
            for (name, object) in [
                (NSView.boundsDidChangeNotification, clipView as NSView),
                (NSView.frameDidChangeNotification, clipView as NSView),
                (NSView.frameDidChangeNotification, scrollView.documentView),
            ] {
                guard let object else { continue }
                observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.report()
                    }
                })
            }
            report()
        }

        private func report() {
            guard let scrollView else { return }
            let clip = scrollView.contentView.bounds
            let offset = clip.origin.y + scrollView.contentInsets.top
            let contentHeight = scrollView.documentView?.frame.height ?? 0
            let edges = ScrollEdges(
                isScrolled: offset > 1,
                hasMoreBelow: clip.maxY < contentHeight - 1
            )
            guard edges != lastValue else { return }
            lastValue = edges
            onChange(edges)
        }

        /// The observer is the list's background, so the list's scroll view is the one that
        /// covers the same area of the window. Walk up and search each ancestor's subtree for it.
        private static func findScrollView(near view: NSView) -> NSScrollView? {
            guard view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else { return nil }
            let target = view.convert(view.bounds, to: nil)

            var ancestor = view.superview
            while let current = ancestor {
                if let match = scrollView(in: current, matching: target) {
                    return match
                }
                ancestor = current.superview
            }
            return nil
        }

        private static func scrollView(in root: NSView, matching target: NSRect) -> NSScrollView? {
            for subview in root.subviews {
                if let scrollView = subview as? NSScrollView {
                    let frame = scrollView.convert(scrollView.bounds, to: nil)
                    let overlap = frame.intersection(target)
                    if !overlap.isNull, overlap.width * overlap.height >= 0.8 * target.width * target.height {
                        return scrollView
                    }
                    continue
                }
                if let match = scrollView(in: subview, matching: target) {
                    return match
                }
            }
            return nil
        }
    }
}

// MARK: - Overlays

/// Confirmation in the split style: frosted card, 8 pt buttons, destructive action in red.
private struct DeleteConfirmationOverlay: View {
    let title: String
    let message: String
    let actionTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isConfirmHovered = false
    @State private var isCancelHovered = false
    @State private var textBlockHeight: CGFloat = 40
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.solidAccents) private var solidAccents
    @Environment(\.l10n) private var l10n

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: solidAccents)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                // Square plate as tall as the text block (title + message), measured from the text.
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.red.opacity(palette.isDark ? 0.18 : 0.10))
                    .frame(width: textBlockHeight, height: textBlockHeight)
                    .overlay {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.red.opacity(0.85))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)

                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { textBlockHeight = geometry.size.height }
                            .onChange(of: geometry.size.height) { textBlockHeight = $0 }
                    }
                )
            }

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text(l10n("Cancel", "Отмена"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(palette.solid ? palette.solidControl(isCancelHovered ? 1 : 0) : (isCancelHovered ? palette.controlHoverBackground : palette.placeholderBackground))
                                .shadow(color: palette.solid ? palette.controlShadow : .clear, radius: ThemePalette.controlShadowRadius, y: 1)
                        }
                }
                .buttonStyle(.plain)
                .onHover { isCancelHovered = $0 }

                Button(action: onConfirm) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.solid ? Color.white : Color.red.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    palette.solid
                                        ? ThemePalette.darken(ThemePalette.solidDestructive, by: isConfirmHovered ? 0.08 : 0)
                                        : Color.red.opacity((palette.isDark ? 0.2 : 0.12) + (isConfirmHovered ? 0.08 : 0))
                                )
                                .shadow(color: palette.solid ? palette.controlShadow : .clear, radius: ThemePalette.controlShadowRadius, y: 1)
                        }
                }
                .buttonStyle(.plain)
                .onHover { isConfirmHovered = $0 }
            }
        }
        .padding(16)
        .frame(width: 300)
        .background {
            ZStack {
                NativeGlassEffectView(style: .regular, cornerRadius: 14)
                palette.sidebarTint
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        )
        .shadow(color: palette.shadow(0.22), radius: 24, y: 10)
    }
}

private struct ScrollBarAppearanceSetter: NSViewRepresentable {
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.postsFrameChangedNotifications = false
        DispatchQueue.main.async {
            applyAppearance(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyAppearance(from: nsView)
        }
    }

    private func applyAppearance(from view: NSView) {
        guard let scrollView = scrollView(containing: view) else {
            return
        }

        let scrollerAppearanceName: NSAppearance.Name = colorScheme == .dark ? .darkAqua : .aqua
        let scrollerAppearance = NSAppearance(named: scrollerAppearanceName)
        let knobStyle: NSScroller.KnobStyle = colorScheme == .dark ? .light : .dark
        // Thin overlay scrollers that only show while scrolling, even when the system setting
        // (or an attached mouse) asks for always-visible legacy scrollers.
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.verticalScroller?.appearance = scrollerAppearance
        scrollView.horizontalScroller?.appearance = scrollerAppearance
        scrollView.verticalScroller?.knobStyle = knobStyle
        scrollView.horizontalScroller?.knobStyle = knobStyle
    }

    private func scrollView(containing view: NSView) -> NSScrollView? {
        if let scrollView = view.enclosingScrollView {
            return scrollView
        }

        var ancestor = view.superview
        while let current = ancestor {
            if let scrollView = firstScrollView(in: current) {
                return scrollView
            }
            ancestor = current.superview
        }

        if let contentView = view.window?.contentView {
            return firstScrollView(in: contentView)
        }

        return nil
    }

    private func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }

        for subview in view.subviews {
            if let scrollView = firstScrollView(in: subview) {
                return scrollView
            }
        }

        return nil
    }
}
